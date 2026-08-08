import { completeMobileAuth, exchangeMobileAuth, startMobileAuth } from "./auth-handoff";
import { AuthEnv, createAuth } from "./auth";
import { errorResponse, HttpError, jsonBody, notFound, record } from "./http";
import { accountProvider, cleanupPendingAccountDeletions, requireRecentSession, requireSession, revokeProviderGrant } from "./session";
import { activatePending, cancelPending, createPending, deleteGuide, readPhoto, snapshot, updateGuide, uploadPhoto } from "./sync";

export async function routeWorker(request: Request, env: AuthEnv): Promise<Response> {
  try {
    const url = new URL(request.url);
    const { method } = request;
    const { pathname } = url;
    if (pathname.startsWith("/api/auth/")) return await routeAuthHandler(request, env, url);
    if (method === "GET" && pathname === "/v1/auth/start") return await startMobileAuth(request, env);
    if (method === "GET" && pathname === "/v1/auth/complete") return await completeMobileAuth(request, env);
    if (method === "POST" && pathname === "/v1/auth/exchange") return await exchangeMobileAuth(request, env);
    if (method === "POST" && pathname === "/v1/auth/sign-out") return await signOut(request, env, url);
    if (method === "GET" && pathname === "/v1/account") return await account(request, env);
    if (method === "DELETE" && pathname === "/v1/account") return await deleteAccount(request, env);
    if (method === "GET" && pathname === "/v1/sync/snapshot") return await snapshot(request, env);

    const guide = /^\/v1\/sync\/guides\/([^/]+)$/.exec(pathname);
    if (guide) {
      const guideID = decodeURIComponent(guide[1]!);
      if (!validGuideID(guideID)) throw notFound();
      if (method === "PUT") return await updateGuide(request, env, guideID);
      if (method === "DELETE") return await deleteGuide(request, env, guideID);
    }
    const pending = /^\/v1\/sync\/guides\/([^/]+)\/pending$/.exec(pathname);
    if (pending && (method === "PUT" || method === "DELETE")) {
      const guideID = decodeURIComponent(pending[1]!);
      if (!validGuideID(guideID)) throw notFound();
      return method === "PUT"
        ? await createPending(request, env, guideID)
        : await cancelPending(request, env, guideID);
    }
    const activation = /^\/v1\/sync\/guides\/([^/]+)\/activate$/.exec(pathname);
    if (activation && method === "POST") {
      const guideID = decodeURIComponent(activation[1]!);
      if (!validGuideID(guideID)) throw notFound();
      return await activatePending(request, env, guideID);
    }
    const photo = /^\/v1\/sync\/guides\/([^/]+)\/photos\/([0-9]+)$/.exec(pathname);
    if (photo) {
      const guideID = decodeURIComponent(photo[1]!);
      const index = Number(photo[2]);
      if (!validGuideID(guideID) || !Number.isInteger(index) || index < 0 || index > 2) throw notFound();
      if (method === "PUT") return await uploadPhoto(request, env, guideID, index);
      if (method === "GET") return await readPhoto(request, env, guideID, index);
    }
    throw notFound();
  } catch (error) {
    return errorResponse(error);
  }
}

async function routeAuthHandler(request: Request, env: AuthEnv, url: URL): Promise<Response> {
  const isProviderCallback = /^\/api\/auth\/callback\/(apple|google)$/.test(url.pathname);
  if (!isProviderCallback && url.pathname !== "/api/auth/error") return errorResponse(notFound());
  return createAuth(env, url.origin).handler(request);
}

async function signOut(request: Request, env: AuthEnv, url: URL): Promise<Response> {
  const auth = createAuth(env, url.origin);
  const response = await auth.handler(
    new Request(`${url.origin}/api/auth/sign-out`, {
      headers: request.headers,
      method: "POST"
    })
  );
  if (!response.ok) throw new HttpError(401, "unauthenticated", "A valid bearer session is required");
  return new Response(null, { status: 204 });
}

async function account(request: Request, env: AuthEnv): Promise<Response> {
  const owner = await requireSession(request, env);
  const provider = await accountProvider(env, owner.id);
  return Response.json({ email: owner.email, id: owner.id, name: owner.name, provider: provider.provider });
}

async function deleteAccount(request: Request, env: AuthEnv): Promise<Response> {
  const body = record(await jsonBody(request));
  if (body.confirmation !== "DELETE") throw new HttpError(400, "confirmation_required", "confirmation must equal DELETE");
  const owner = await requireSession(request, env, true);
  requireRecentSession(owner);
  await env.DB.prepare(
    "INSERT OR IGNORE INTO account_deletions (user_id, provider_revoked, started_at_ms) VALUES (?, 0, ?)"
  ).bind(owner.id, Date.now()).run();
  const deletion = await env.DB.prepare("SELECT provider_revoked FROM account_deletions WHERE user_id = ?")
    .bind(owner.id)
    .first<{ provider_revoked: number }>();
  if (!deletion?.provider_revoked) {
    await revokeProviderGrant(request, owner, env);
    const recorded = await env.DB.prepare("UPDATE account_deletions SET provider_revoked = 1 WHERE user_id = ?")
      .bind(owner.id)
      .run();
    if (recorded.meta.changes !== 1) {
      throw new HttpError(503, "account_deletion_unavailable", "Provider revocation could not be recorded");
    }
  }
  const deleted = await env.DB.prepare('DELETE FROM "user" WHERE id = ?').bind(owner.id).run();
  if (deleted.meta.changes < 1) throw new HttpError(503, "account_deletion_unavailable", "The account could not be deleted");
  await cleanupPendingAccountDeletions(env);
  return new Response(null, { status: 204 });
}

function validGuideID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}
