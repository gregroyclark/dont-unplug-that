import { describe, expect, it } from "vitest";

import { routeWorker } from "../src/router";
import { cleanupPendingGuidePhotoDeletions } from "../src/sync";
import { descriptor, guide, request, seedOwner, validJpeg, workerEnv } from "./support";

const guideID = "11111111-1111-4111-8111-111111111111";

describe("owner-scoped guide sync", () => {
  it("migrates Better Auth and sync tables into isolated D1", async () => {
    const tables = await workerEnv.DB.prepare("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name").all<{ name: string }>();
    expect(tables.results.map((row) => row.name)).toEqual(expect.arrayContaining([
      "account", "account_deletions", "auth_handoff", "guide_photo_deletions", "session", "sync_guide_photos", "sync_guides", "sync_tombstones", "user", "verification"
    ]));
  });

  it("keeps pending guides invisible, requires all photos for activation, and never leaks them cross-owner", async () => {
    await seedOwner("owner-a", "token-a");
    await seedOwner("owner-b", "token-b");
    const photo = await descriptor();
    const withoutPrecondition = await routeWorker(
      request(`/v1/sync/guides/${guideID}/pending`, "token-a", {
        body: JSON.stringify({ guide: guide(guideID), photos: [photo] }),
        headers: { "content-type": "application/json" },
        method: "PUT"
      }),
      workerEnv
    );
    expect(withoutPrecondition.status).toBe(428);
    const create = await routeWorker(
      request(`/v1/sync/guides/${guideID}/pending`, "token-a", {
        body: JSON.stringify({ guide: guide(guideID), photos: [photo] }),
        headers: { "content-type": "application/json", "if-none-match": "*" },
        method: "PUT"
      }),
      workerEnv
    );
    expect(create.status).toBe(201);

    const ownSnapshot = await routeWorker(request("/v1/sync/snapshot", "token-a"), workerEnv);
    expect((await ownSnapshot.json() as { guides: unknown[] }).guides).toEqual([]);
    const foreignActivate = await routeWorker(
      request(`/v1/sync/guides/${guideID}/activate`, "token-b", { headers: { "if-match": '"0"' }, method: "POST" }),
      workerEnv
    );
    expect(foreignActivate.status).toBe(404);
    const missingPhoto = await routeWorker(
      request(`/v1/sync/guides/${guideID}/activate`, "token-a", { headers: { "if-match": '"0"' }, method: "POST" }),
      workerEnv
    );
    expect(missingPhoto.status).toBe(409);
    expect((await missingPhoto.json() as { error: { code: string } }).error.code).toBe("photos_incomplete");
  });

  it("cancels a pending guide, removes uploaded photos, and prevents ID reuse", async () => {
    await seedOwner("owner-a", "token-a");
    const photo = await descriptor();
    const image = validJpeg();
    await routeWorker(
      request(`/v1/sync/guides/${guideID}/pending`, "token-a", {
        body: JSON.stringify({ guide: guide(guideID), photos: [photo] }),
        headers: { "content-type": "application/json", "if-none-match": "*" },
        method: "PUT"
      }),
      workerEnv
    );
    await routeWorker(
      request(`/v1/sync/guides/${guideID}/photos/0`, "token-a", {
        body: image,
        headers: { "content-digest": await digest(image), "content-length": String(image.byteLength), "content-type": "image/jpeg" },
        method: "PUT"
      }),
      workerEnv
    );

    const cancelled = await routeWorker(
      request(`/v1/sync/guides/${guideID}/pending`, "token-a", {
        headers: { "if-match": '"0"' },
        method: "DELETE"
      }),
      workerEnv
    );

    expect(cancelled.status, await cancelled.clone().text()).toBe(204);
    expect(await workerEnv.DB.prepare("SELECT 1 FROM sync_guides WHERE owner_id = ? AND id = ?").bind("owner-a", guideID).first()).toBeNull();
    expect(await workerEnv.GUIDE_PHOTOS.head(`owners/owner-a/guides/${guideID}/photos/0.jpg`)).toBeNull();
    expect(await workerEnv.DB.prepare("SELECT 1 FROM guide_photo_deletions WHERE owner_id = ? AND guide_id = ?").bind("owner-a", guideID).first()).toBeNull();
    expect(await workerEnv.DB.prepare("SELECT revision FROM sync_tombstones WHERE owner_id = ? AND id = ?").bind("owner-a", guideID).first<{ revision: number }>()).toEqual({ revision: 1 });

    const recreate = await routeWorker(
      request(`/v1/sync/guides/${guideID}/pending`, "token-a", {
        body: JSON.stringify({ guide: guide(guideID), photos: [photo] }),
        headers: { "content-type": "application/json", "if-none-match": "*" },
        method: "PUT"
      }),
      workerEnv
    );
    expect(recreate.status).toBe(409);
  });

  it("enforces conditional whole-guide writers and tombstones prevent resurrection", async () => {
    await seedOwner("owner-a", "token-a");
    const photo = await descriptor();
    await routeWorker(
      request(`/v1/sync/guides/${guideID}/pending`, "token-a", {
        body: JSON.stringify({ guide: guide(guideID), photos: [photo] }),
        headers: { "content-type": "application/json", "if-none-match": "*" },
        method: "PUT"
      }),
      workerEnv
    );
    const image = validJpeg();
    await routeWorker(
      request(`/v1/sync/guides/${guideID}/photos/0`, "token-a", {
        body: image,
        headers: { "content-digest": await digest(image), "content-length": String(image.byteLength), "content-type": "image/jpeg" },
        method: "PUT"
      }),
      workerEnv
    );
    const activated = await routeWorker(
      request(`/v1/sync/guides/${guideID}/activate`, "token-a", { headers: { "if-match": '"0"' }, method: "POST" }),
      workerEnv
    );
    expect(activated.status).toBe(200);
    const privateRead = await routeWorker(request(`/v1/sync/guides/${guideID}/photos/0`, "token-a"), workerEnv);
    expect(privateRead.status).toBe(200);
    expect(privateRead.headers.get("cache-control")).toBe("private, no-store");
    await seedOwner("owner-b", "token-b");
    const foreignRead = await routeWorker(request(`/v1/sync/guides/${guideID}/photos/0`, "token-b"), workerEnv);
    expect(foreignRead.status).toBe(404);
    const updatedGuide = guide(guideID) as { [key: string]: unknown };
    updatedGuide.title = "First writer";
    const firstWriter = await routeWorker(
      request(`/v1/sync/guides/${guideID}`, "token-a", {
        body: JSON.stringify({ guide: updatedGuide }),
        headers: { "content-type": "application/json", "if-match": '"1"' },
        method: "PUT"
      }),
      workerEnv
    );
    expect(firstWriter.status).toBe(200);
    const secondWriter = await routeWorker(
      request(`/v1/sync/guides/${guideID}`, "token-a", {
        body: JSON.stringify({ guide: guide(guideID) }),
        headers: { "content-type": "application/json", "if-match": '"1"' },
        method: "PUT"
      }),
      workerEnv
    );
    expect(secondWriter.status).toBe(409);
    expect((await secondWriter.json() as { error: { current: { revision: number } } }).error.current.revision).toBe(2);
    const staleDelete = await routeWorker(
      request(`/v1/sync/guides/${guideID}`, "token-a", { headers: { "if-match": '"1"' }, method: "DELETE" }),
      workerEnv
    );
    expect(staleDelete.status).toBe(409);
    expect(await workerEnv.DB.prepare("SELECT 1 FROM guide_photo_deletions WHERE owner_id = ? AND guide_id = ?")
      .bind("owner-a", guideID)
      .first()).toBeNull();
    expect(await workerEnv.GUIDE_PHOTOS.head(`owners/owner-a/guides/${guideID}/photos/0.jpg`)).not.toBeNull();
    const deleted = await routeWorker(
      request(`/v1/sync/guides/${guideID}`, "token-a", { headers: { "if-match": '"2"' }, method: "DELETE" }),
      workerEnv
    );
    expect(deleted.status, await deleted.clone().text()).toBe(204);
    const resurrect = await routeWorker(
      request(`/v1/sync/guides/${guideID}/pending`, "token-a", {
        body: JSON.stringify({ guide: guide(guideID), photos: [photo] }),
        headers: { "content-type": "application/json", "if-none-match": "*" },
        method: "PUT"
      }),
      workerEnv
    );
    expect(resurrect.status).toBe(409);
    expect((await resurrect.json() as { error: { code: string } }).error.code).toBe("guide_deleted");
  });

  it("finishes private photo cleanup from a durable guide marker", async () => {
    await workerEnv.GUIDE_PHOTOS.put(
      `owners/owner-a/guides/${guideID}/photos/0.jpg`,
      new Uint8Array([1, 2, 3])
    );
    await workerEnv.DB.prepare(
      "INSERT INTO guide_photo_deletions (owner_id, guide_id, photo_count, started_at_ms) VALUES (?, ?, 1, ?)"
    ).bind("owner-a", guideID, Date.now()).run();

    await cleanupPendingGuidePhotoDeletions(workerEnv);

    expect(await workerEnv.GUIDE_PHOTOS.head(`owners/owner-a/guides/${guideID}/photos/0.jpg`)).toBeNull();
    expect(await workerEnv.DB.prepare("SELECT 1 FROM guide_photo_deletions WHERE owner_id = ? AND guide_id = ?")
      .bind("owner-a", guideID)
      .first()).toBeNull();
  });
});

async function digest(bytes: Uint8Array): Promise<string> {
  const hashed = await crypto.subtle.digest("SHA-256", bytes);
  let binary = "";
  for (const value of new Uint8Array(hashed)) binary += String.fromCharCode(value);
  return `sha-256=:${btoa(binary)}:`;
}
