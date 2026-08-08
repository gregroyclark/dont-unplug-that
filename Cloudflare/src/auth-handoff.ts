import { AuthEnv, createAuth } from "./auth";
import { HttpError, base64url, jsonBody, record, sha256, stringField } from "./http";

type Handoff = {
  id: string;
  callback_state: string;
  code_hash: string | null;
  pkce_challenge: string;
  status: "pending" | "ready" | "consumed";
  user_id: string | null;
  expires_at_ms: number;
};

const flowLifetime = 600_000;
const codeLifetime = 120_000;
const maximumActiveFlowsPerClient = 5;
const maximumActiveFlows = 10_000;

export async function startMobileAuth(request: Request, env: AuthEnv): Promise<Response> {
  const url = new URL(request.url);
  const provider = url.searchParams.get("provider");
  const state = url.searchParams.get("state");
  const challenge = url.searchParams.get("code_challenge");
  if ((provider !== "apple" && provider !== "google") || !validRandom(state) || !validRandom(challenge) || url.searchParams.get("code_challenge_method") !== "S256") {
    throw new HttpError(400, "invalid_auth_request", "provider, state, S256 PKCE challenge are required");
  }
  const now = Date.now();
  const flowID = crypto.randomUUID();
  const stateHash = await sha256(state);
  const clientHash = await sha256(`${env.BETTER_AUTH_SECRET}:${request.headers.get("cf-connecting-ip") ?? "unknown"}`);
  await env.DB.prepare("DELETE FROM auth_handoff WHERE expires_at_ms < ? OR status = 'consumed'").bind(now).run();
  const inserted = await env.DB.prepare(
    "INSERT OR IGNORE INTO auth_handoff (id, callback_state, state_hash, provider, client_hash, pkce_challenge, status, created_at_ms, expires_at_ms) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?)"
  )
    .bind(flowID, state, stateHash, provider, clientHash, challenge, now, now + flowLifetime)
    .run();
  if (inserted.meta.changes !== 1) throw new HttpError(409, "auth_flow_exists", "This state value was already used");
  const [clientCount, totalCount] = await env.DB.batch([
    env.DB.prepare("SELECT COUNT(*) AS count FROM auth_handoff WHERE client_hash = ? AND expires_at_ms >= ?").bind(clientHash, now),
    env.DB.prepare("SELECT COUNT(*) AS count FROM auth_handoff WHERE expires_at_ms >= ?").bind(now)
  ]);
  if (count(clientCount) > maximumActiveFlowsPerClient || count(totalCount) > maximumActiveFlows) {
    await env.DB.prepare("DELETE FROM auth_handoff WHERE id = ?").bind(flowID).run();
    throw new HttpError(429, "auth_rate_limited", "Too many sign-in attempts are active. Try again shortly");
  }

  const origin = url.origin;
  const auth = createAuth(env, origin);
  const signIn = await auth.handler(
    new Request(`${origin}/api/auth/sign-in/social`, {
      body: JSON.stringify({
        callbackURL: `${origin}/v1/auth/complete?flow=${encodeURIComponent(flowID)}`,
        provider
      }),
      headers: { "content-type": "application/json" },
      method: "POST"
    })
  );
  if (!signIn.ok) {
    await env.DB.prepare("DELETE FROM auth_handoff WHERE id = ?").bind(flowID).run();
    throw new HttpError(503, "auth_unavailable", "The identity provider could not be started");
  }
  const data = (await signIn.json()) as { url?: unknown };
  if (typeof data.url !== "string") {
    await env.DB.prepare("DELETE FROM auth_handoff WHERE id = ?").bind(flowID).run();
    throw new HttpError(503, "auth_unavailable", "The identity provider did not return an authorization URL");
  }
  // Better Auth can use a cookie-backed OAuth state strategy. Preserve every
  // Set-Cookie value while turning its JSON response into the browser redirect.
  const headers = new Headers({ location: data.url });
  for (const cookie of signIn.headers.getSetCookie()) headers.append("set-cookie", cookie);
  return new Response(null, { headers, status: 302 });
}

export async function completeMobileAuth(request: Request, env: AuthEnv): Promise<Response> {
  const url = new URL(request.url);
  const flowID = url.searchParams.get("flow");
  if (!flowID) throw new HttpError(400, "invalid_auth_flow", "flow is required");
  const handoff = await env.DB.prepare("SELECT * FROM auth_handoff WHERE id = ?").bind(flowID).first<Handoff>();
  if (!handoff || handoff.status !== "pending" || handoff.expires_at_ms < Date.now()) {
    throw new HttpError(401, "auth_flow_expired", "The sign-in flow is invalid or expired");
  }
  const auth = createAuth(env, url.origin);
  const session = await auth.api.getSession({ headers: request.headers });
  if (!session) throw new HttpError(401, "unauthenticated", "The browser sign-in did not create a session");
  const generated = await auth.api.generateOneTimeToken({ headers: request.headers });
  const codeHash = await sha256(generated.token);
  const now = Date.now();
  const updated = await env.DB.prepare(
    "UPDATE auth_handoff SET code_hash = ?, status = 'ready', user_id = ?, expires_at_ms = ? WHERE id = ? AND status = 'pending' AND expires_at_ms >= ?"
  )
    .bind(codeHash, session.user.id, now + codeLifetime, flowID, now)
    .run();
  if (updated.meta.changes !== 1) throw new HttpError(401, "auth_flow_expired", "The sign-in flow has expired");
  return Response.redirect(
    `dontunplugthat://auth/callback?code=${encodeURIComponent(generated.token)}&state=${encodeURIComponent(handoff.callback_state)}`,
    302
  );
}

export async function exchangeMobileAuth(request: Request, env: AuthEnv): Promise<Response> {
  const body = record(await jsonBody(request));
  const code = stringField(body.code, "code");
  const state = stringField(body.state, "state");
  const codeVerifier = stringField(body.codeVerifier, "codeVerifier");
  const stateHash = await sha256(state);
  const codeHash = await sha256(code);
  const handoff = await env.DB.prepare(
    "SELECT * FROM auth_handoff WHERE state_hash = ? AND code_hash = ?"
  )
    .bind(stateHash, codeHash)
    .first<Handoff>();
  if (!handoff || handoff.status !== "ready" || handoff.expires_at_ms < Date.now() || !(await verifyPKCE(codeVerifier, handoff.pkce_challenge))) {
    throw new HttpError(401, "invalid_handoff", "The handoff code, state, or verifier is invalid");
  }
  const consumed = await env.DB.prepare(
    "UPDATE auth_handoff SET status = 'consumed', consumed_at_ms = ? WHERE id = ? AND status = 'ready' AND expires_at_ms >= ?"
  )
    .bind(Date.now(), handoff.id, Date.now())
    .run();
  if (consumed.meta.changes !== 1) throw new HttpError(401, "invalid_handoff", "The handoff code was already used");

  const origin = new URL(request.url).origin;
  const auth = createAuth(env, origin);
  const verified = await auth.handler(
    new Request(`${origin}/api/auth/one-time-token/verify`, {
      body: JSON.stringify({ token: code }),
      headers: { "content-type": "application/json" },
      method: "POST"
    })
  );
  const bearerToken = verified.headers.get("set-auth-token");
  if (!verified.ok || !bearerToken) {
    throw new HttpError(503, "auth_handoff_unavailable", "Better Auth did not issue a bearer session");
  }
  await env.DB.prepare("DELETE FROM auth_handoff WHERE id = ?").bind(handoff.id).run();
  return Response.json(
    { status: "ok" },
    { headers: { "access-control-expose-headers": "set-auth-token", "set-auth-token": bearerToken } }
  );
}

function count(result: D1Result): number {
  const row = result.results[0] as { count?: unknown } | undefined;
  return typeof row?.count === "number" ? row.count : Number(row?.count ?? 0);
}

function validRandom(value: string | null): value is string {
  return value !== null && value.length >= 16 && value.length <= 512 && /^[A-Za-z0-9._~-]+$/.test(value);
}

async function verifyPKCE(verifier: string, expectedChallenge: string): Promise<boolean> {
  return base64url(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier))) === expectedChallenge;
}

export function testPKCEChallenge(verifier: string): Promise<string> {
  return sha256(verifier);
}
