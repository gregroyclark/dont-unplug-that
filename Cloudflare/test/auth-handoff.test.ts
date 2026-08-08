import { describe, expect, it } from "vitest";

import { testPKCEChallenge } from "../src/auth-handoff";
import { createAuth } from "../src/auth";
import { sha256 } from "../src/http";
import { routeWorker } from "../src/router";
import { request, seedOwner, workerEnv } from "./support";

describe("mobile auth handoff", () => {
  it("uses encrypted provider tokens and preserves Better Auth's OAuth state cookie", async () => {
    const auth = createAuth(workerEnv, "https://api.example.test");
    expect(auth.options.account?.encryptOAuthTokens).toBe(true);

    const state = "state-value-which-is-long-enough";
    const verifier = "verifier-value-which-is-long-enough";
    const response = await routeWorker(new Request(
      `https://api.example.test/v1/auth/start?provider=google&state=${state}&code_challenge=${await testPKCEChallenge(verifier)}&code_challenge_method=S256`
    ), workerEnv);
    expect(response.status).toBe(302);
    expect(response.headers.get("location")).toContain("accounts.google.com");
    expect(response.headers.get("set-cookie")).toBeTruthy();

    const directVerify = await routeWorker(new Request("https://api.example.test/api/auth/one-time-token/verify", {
      body: JSON.stringify({ token: "stolen-callback-code" }),
      headers: { "content-type": "application/json" },
      method: "POST"
    }), workerEnv);
    expect(directVerify.status).toBe(404);
  });

  it("stores only hashes and rejects a wrong verifier without consuming the handoff", async () => {
    const code = "handoff-code-which-is-not-stored";
    const state = "state-value-which-is-long-enough";
    const verifier = "verifier-value-which-is-long-enough";
    const id = crypto.randomUUID();
    await seedOwner("owner", "better-auth-session-token");
    const now = new Date().toISOString();
    await workerEnv.DB.prepare(
      'INSERT INTO "verification" ("id", "identifier", "value", "expiresAt", "createdAt", "updatedAt") VALUES (?, ?, ?, ?, ?, ?)'
    )
      .bind(crypto.randomUUID(), `one-time-token:${await sha256(code)}`, "better-auth-session-token", new Date(Date.now() + 60_000).toISOString(), now, now)
      .run();
    await workerEnv.DB.prepare(
      "INSERT INTO auth_handoff (id, callback_state, state_hash, code_hash, provider, client_hash, pkce_challenge, status, user_id, created_at_ms, expires_at_ms) VALUES (?, ?, ?, ?, 'google', 'test-client', ?, 'ready', ?, ?, ?)"
    )
      .bind(id, state, await sha256(state), await sha256(code), await testPKCEChallenge(verifier), "owner", Date.now(), Date.now() + 60_000)
      .run();
    const wrong = await routeWorker(request("/v1/auth/exchange", "unused", {
      body: JSON.stringify({ code, codeVerifier: "wrong-verifier", state }),
      headers: { "content-type": "application/json" },
      method: "POST"
    }), workerEnv);
    expect(wrong.status).toBe(401);
    const stored = await workerEnv.DB.prepare("SELECT status, code_hash FROM auth_handoff WHERE id = ?").bind(id).first<{ status: string; code_hash: string }>();
    expect(stored?.status).toBe("ready");
    expect(stored?.code_hash).toBe(await sha256(code));
    expect(stored?.code_hash).not.toBe(code);
    const exchanged = await routeWorker(request("/v1/auth/exchange", "unused", {
      body: JSON.stringify({ code, codeVerifier: verifier, state }),
      headers: { "content-type": "application/json" },
      method: "POST"
    }), workerEnv);
    expect(exchanged.status).toBe(200);
    expect(exchanged.headers.get("set-auth-token")).toBeTruthy();
    const replay = await routeWorker(request("/v1/auth/exchange", "unused", {
      body: JSON.stringify({ code, codeVerifier: verifier, state }),
      headers: { "content-type": "application/json" },
      method: "POST"
    }), workerEnv);
    expect(replay.status).toBe(401);
  });

  it("rejects an expired handoff before Better Auth is invoked", async () => {
    const code = "expired-handoff-code-which-is-not-stored";
    const state = "expired-state-value-which-is-long-enough";
    const verifier = "expired-verifier-value-which-is-long-enough";
    await workerEnv.DB.prepare(
      "INSERT INTO auth_handoff (id, callback_state, state_hash, code_hash, provider, client_hash, pkce_challenge, status, created_at_ms, expires_at_ms) VALUES (?, ?, ?, ?, 'google', 'test-client', ?, 'ready', ?, ?)"
    )
      .bind(crypto.randomUUID(), state, await sha256(state), await sha256(code), await testPKCEChallenge(verifier), Date.now() - 120_000, Date.now() - 1)
      .run();
    const response = await routeWorker(request("/v1/auth/exchange", "unused", {
      body: JSON.stringify({ code, codeVerifier: verifier, state }),
      headers: { "content-type": "application/json" },
      method: "POST"
    }), workerEnv);
    expect(response.status).toBe(401);
  });

  it("cleans expired handoffs and bounds active public sign-in rows", async () => {
    await workerEnv.DB.prepare(
      "INSERT INTO auth_handoff (id, callback_state, state_hash, provider, client_hash, pkce_challenge, status, created_at_ms, expires_at_ms) VALUES (?, 'expired-state', ?, 'google', 'expired-client', 'challenge', 'pending', ?, ?)"
    ).bind(crypto.randomUUID(), await sha256("expired-state"), Date.now() - 20_000, Date.now() - 10_000).run();

    for (let index = 0; index < 6; index += 1) {
      const state = `rate-limited-state-value-${index}`;
      const response = await routeWorker(new Request(
        `https://api.example.test/v1/auth/start?provider=google&state=${state}&code_challenge=${await testPKCEChallenge(`verifier-${index}`)}&code_challenge_method=S256`,
        { headers: { "cf-connecting-ip": "203.0.113.7" } }
      ), workerEnv);
      expect(response.status).toBe(index < 5 ? 302 : 429);
    }
    expect(await workerEnv.DB.prepare("SELECT 1 FROM auth_handoff WHERE callback_state = 'expired-state'").first()).toBeNull();
    const active = await workerEnv.DB.prepare("SELECT COUNT(*) AS count FROM auth_handoff WHERE client_hash != 'expired-client'")
      .first<{ count: number }>();
    expect(active?.count).toBe(5);
  });
});
