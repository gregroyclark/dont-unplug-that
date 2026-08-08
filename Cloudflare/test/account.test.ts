import { afterEach, describe, expect, it, vi } from "vitest";

import { routeWorker } from "../src/router";
import { cleanupPendingAccountDeletions } from "../src/session";
import { request, seedOwner, workerEnv } from "./support";

describe("account deletion", () => {
  afterEach(() => vi.restoreAllMocks());

  it("revokes the provider before removing private objects and account data", async () => {
    await seedOwner("owner", "token");
    await workerEnv.GUIDE_PHOTOS.put("owners/owner/guides/guide/photos/0.jpg", new Uint8Array([1, 2, 3]));
    const revoke = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status: 200 }));

    const response = await routeWorker(request("/v1/account", "token", {
      body: JSON.stringify({ confirmation: "DELETE" }),
      headers: { "content-type": "application/json" },
      method: "DELETE"
    }), workerEnv);

    expect(response.status, await response.clone().text()).toBe(204);
    expect(await workerEnv.DB.prepare('SELECT 1 FROM "user" WHERE id = ?').bind("owner").first()).toBeNull();
    expect(await workerEnv.DB.prepare("SELECT 1 FROM account_deletions WHERE user_id = ?").bind("owner").first()).toBeNull();
    expect(await workerEnv.GUIDE_PHOTOS.head("owners/owner/guides/guide/photos/0.jpg")).toBeNull();
    expect(revoke).toHaveBeenCalledOnce();
    expect(revoke.mock.calls[0]?.[0]).toBe("https://oauth2.googleapis.com/revoke");
  });

  it("blocks account traffic during deletion and retries durable object cleanup", async () => {
    await seedOwner("owner", "token");
    await workerEnv.DB.prepare(
      "INSERT INTO account_deletions (user_id, provider_revoked, started_at_ms) VALUES (?, 1, ?)"
    ).bind("owner", Date.now()).run();
    await workerEnv.GUIDE_PHOTOS.put("owners/owner/guides/guide/photos/0.jpg", new Uint8Array([1, 2, 3]));

    const blocked = await routeWorker(request("/v1/sync/snapshot", "token"), workerEnv);
    expect(blocked.status).toBe(409);
    expect((await blocked.json() as { error: { code: string } }).error.code).toBe("account_deleting");

    const resumed = await routeWorker(request("/v1/account", "token", {
      body: JSON.stringify({ confirmation: "DELETE" }),
      headers: { "content-type": "application/json" },
      method: "DELETE"
    }), workerEnv);
    expect(resumed.status, await resumed.clone().text()).toBe(204);
    expect(await workerEnv.DB.prepare('SELECT 1 FROM "user" WHERE id = ?').bind("owner").first()).toBeNull();
    expect(await workerEnv.GUIDE_PHOTOS.head("owners/owner/guides/guide/photos/0.jpg")).toBeNull();
  });

  it("finishes orphaned R2 cleanup from a durable deletion marker", async () => {
    await workerEnv.DB.prepare(
      "INSERT INTO account_deletions (user_id, provider_revoked, started_at_ms) VALUES ('deleted-owner', 1, ?)"
    ).bind(Date.now()).run();
    await workerEnv.GUIDE_PHOTOS.put("owners/deleted-owner/guides/guide/photos/0.jpg", new Uint8Array([1]));

    await cleanupPendingAccountDeletions(workerEnv);

    expect(await workerEnv.GUIDE_PHOTOS.head("owners/deleted-owner/guides/guide/photos/0.jpg")).toBeNull();
    expect(await workerEnv.DB.prepare("SELECT 1 FROM account_deletions WHERE user_id = 'deleted-owner'").first()).toBeNull();
  });

  it("preserves account data when the provider rejects revocation", async () => {
    await seedOwner("owner", "token");
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(null, { status: 400 }));

    const response = await routeWorker(request("/v1/account", "token", {
      body: JSON.stringify({ confirmation: "DELETE" }),
      headers: { "content-type": "application/json" },
      method: "DELETE"
    }), workerEnv);

    expect(response.status).toBe(503);
    expect(await workerEnv.DB.prepare('SELECT 1 FROM "user" WHERE id = ?').bind("owner").first()).not.toBeNull();
    expect(await workerEnv.DB.prepare("SELECT provider_revoked FROM account_deletions WHERE user_id = ?")
      .bind("owner")
      .first<{ provider_revoked: number }>()).toEqual({ provider_revoked: 0 });
  });
});
