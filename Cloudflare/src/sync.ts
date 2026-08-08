import { PhotoDescriptor, validatePendingGuide, validateUpdateGuide } from "./contracts";
import { HttpError, Json, jsonBody, notFound, requireIfNoneMatchStar, requiredIfMatch } from "./http";
import { photoKey, validatePhotoUpload } from "./photos";
import { AuthEnv } from "./auth";
import { requireSession } from "./session";

type GuideRow = {
  id: string;
  state: "pending" | "active";
  revision: number;
  guide_json: string;
  photo_count: number;
  updated_at_ms: number;
};

type PhotoRow = Omit<PhotoDescriptor, "mediaType"> & { r2_key: string };

type GuidePhotoDeletionRow = {
  owner_id: string;
  guide_id: string;
  photo_count: number;
};

export async function snapshot(request: Request, env: AuthEnv): Promise<Response> {
  const owner = await requireSession(request, env);
  const guides = await env.DB.prepare(
    "SELECT id, revision, guide_json, photo_count, updated_at_ms FROM sync_guides WHERE owner_id = ? AND state = 'active' ORDER BY updated_at_ms DESC"
  )
    .bind(owner.id)
    .all<GuideRow>();
  const snapshots = await Promise.all(guides.results.map(async (guide) => activeSnapshot(env.DB, owner.id, guide)));
  const tombstones = await env.DB.prepare(
    "SELECT id, revision, deleted_at_ms FROM sync_tombstones WHERE owner_id = ? ORDER BY deleted_at_ms DESC"
  )
    .bind(owner.id)
    .all<{ id: string; revision: number; deleted_at_ms: number }>();
  return Response.json({
    guides: snapshots,
    tombstones: tombstones.results.map((tombstone) => ({
      deletedAt: tombstone.deleted_at_ms,
      id: tombstone.id,
      revision: tombstone.revision
    }))
  });
}

export async function createPending(request: Request, env: AuthEnv, guideID: string): Promise<Response> {
  const owner = await requireSession(request, env);
  requireIfNoneMatchStar(request);
  const pending = validatePendingGuide(await jsonBody(request), guideID);
  const tombstone = await env.DB.prepare("SELECT 1 FROM sync_tombstones WHERE owner_id = ? AND id = ?")
    .bind(owner.id, guideID)
    .first();
  if (tombstone) throw new HttpError(409, "guide_deleted", "Deleted guide IDs cannot be reused");
  const now = Date.now();
  const created = await env.DB.prepare(
    "INSERT OR IGNORE INTO sync_guides (owner_id, id, state, revision, guide_json, photo_count, created_at_ms, updated_at_ms) VALUES (?, ?, 'pending', 0, ?, ?, ?, ?)"
  )
    .bind(owner.id, guideID, pending.encodedGuide, pending.photos.length, now, now)
    .run();
  if (created.meta.changes !== 1) throw new HttpError(409, "guide_exists", "The guide already exists");
  try {
    await env.DB.batch(
      pending.photos.map((photo) =>
        env.DB
          .prepare(
            "INSERT INTO sync_guide_photos (owner_id, guide_id, photo_index, sha256, byte_count, pixel_width, pixel_height, r2_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
          )
          .bind(owner.id, guideID, photo.index, photo.sha256, photo.byteCount, photo.pixelWidth, photo.pixelHeight, photoKey(owner.id, guideID, photo.index))
      )
    );
  } catch {
    await env.DB.prepare("DELETE FROM sync_guides WHERE owner_id = ? AND id = ? AND state = 'pending'").bind(owner.id, guideID).run();
    throw new HttpError(503, "storage_unavailable", "The pending guide could not be stored");
  }
  return Response.json({ revision: 0, state: "pending" }, { status: 201, headers: { etag: '"0"' } });
}

export async function uploadPhoto(request: Request, env: AuthEnv, guideID: string, index: number): Promise<Response> {
  const owner = await requireSession(request, env);
  const photo = await env.DB.prepare(
    "SELECT p.photo_index AS \"index\", p.sha256, p.byte_count AS byteCount, p.pixel_width AS pixelWidth, p.pixel_height AS pixelHeight, p.r2_key FROM sync_guide_photos p JOIN sync_guides g ON g.owner_id = p.owner_id AND g.id = p.guide_id WHERE p.owner_id = ? AND p.guide_id = ? AND p.photo_index = ? AND g.state = 'pending'"
  )
    .bind(owner.id, guideID, index)
    .first<PhotoRow>();
  if (!photo) throw await guideOrNotFound(env.DB, owner.id, guideID);
  const bytes = await validatePhotoUpload(request, photo);
  const existing = await env.GUIDE_PHOTOS.head(photo.r2_key);
  if (existing) {
    if (existing.size === photo.byteCount && existing.customMetadata?.sha256 === photo.sha256) {
      await requireUploadStillPending(env, owner.id, guideID);
      return new Response(null, { status: 204 });
    }
    throw new HttpError(409, "photo_exists", "A different photo is already uploaded at this index");
  }
  const written = await env.GUIDE_PHOTOS.put(photo.r2_key, bytes, {
    customMetadata: { sha256: photo.sha256 },
    httpMetadata: { contentType: "image/jpeg", cacheControl: "private, no-store" },
    onlyIf: { etagDoesNotMatch: "*" },
    sha256: await crypto.subtle.digest("SHA-256", bytes)
  });
  if (!written) {
    const raced = await env.GUIDE_PHOTOS.head(photo.r2_key);
    if (raced?.size === photo.byteCount && raced.customMetadata?.sha256 === photo.sha256) {
      await requireUploadStillPending(env, owner.id, guideID);
      return new Response(null, { status: 204 });
    }
    throw new HttpError(409, "photo_exists", "A different photo is already uploaded at this index");
  }
  await requireUploadStillPending(env, owner.id, guideID);
  return new Response(null, { status: 204 });
}

async function requireUploadStillPending(env: AuthEnv, ownerID: string, guideID: string): Promise<void> {
  const stillPending = await env.DB.prepare(
    "SELECT 1 FROM sync_guides g JOIN \"user\" u ON u.id = g.owner_id LEFT JOIN account_deletions d ON d.user_id = g.owner_id WHERE g.owner_id = ? AND g.id = ? AND g.state = 'pending' AND d.user_id IS NULL"
  ).bind(ownerID, guideID).first();
  if (!stillPending) {
    await markGuidePhotoDeletion(env.DB, ownerID, guideID, 3);
    await finishGuidePhotoDeletion(env, ownerID, guideID, 3);
    throw new HttpError(409, "upload_cancelled", "The guide or account was deleted during upload");
  }
}

export async function cancelPending(request: Request, env: AuthEnv, guideID: string): Promise<Response> {
  const owner = await requireSession(request, env);
  if (requiredIfMatch(request) !== 0) {
    throw new HttpError(400, "invalid_precondition", "Pending guide cancellation requires revision 0");
  }
  const guide = await env.DB.prepare(
    "SELECT id, state, revision, guide_json, photo_count, updated_at_ms FROM sync_guides WHERE owner_id = ? AND id = ?"
  ).bind(owner.id, guideID).first<GuideRow>();
  if (!guide) {
    const tombstone = await env.DB.prepare(
      "SELECT photo_count FROM sync_tombstones WHERE owner_id = ? AND id = ? AND revision = 1"
    ).bind(owner.id, guideID).first<{ photo_count: number }>();
    if (tombstone) {
      await markGuidePhotoDeletion(env.DB, owner.id, guideID, tombstone.photo_count);
      await finishGuidePhotoDeletion(env, owner.id, guideID, tombstone.photo_count);
    }
    return new Response(null, { status: 204 });
  }
  if (guide.state === "active") {
    throw new HttpError(409, "revision_conflict", "The guide is already active", await activeSnapshot(env.DB, owner.id, guide));
  }
  const now = Date.now();
  const results = await env.DB.batch([
    env.DB.prepare(
      "INSERT INTO sync_tombstones (owner_id, id, revision, photo_count, deleted_at_ms) SELECT owner_id, id, 1, photo_count, ? FROM sync_guides WHERE owner_id = ? AND id = ? AND state = 'pending' AND revision = 0"
    ).bind(now, owner.id, guideID),
    env.DB.prepare(
      "INSERT INTO guide_photo_deletions (owner_id, guide_id, photo_count, started_at_ms) SELECT owner_id, id, photo_count, ? FROM sync_guides WHERE owner_id = ? AND id = ? AND state = 'pending' AND revision = 0 ON CONFLICT (owner_id, guide_id) DO UPDATE SET photo_count = MAX(photo_count, excluded.photo_count)"
    ).bind(now, owner.id, guideID),
    env.DB.prepare("DELETE FROM sync_guides WHERE owner_id = ? AND id = ? AND state = 'pending' AND revision = 0")
      .bind(owner.id, guideID)
  ]);
  if ((results[2]?.meta.changes ?? 0) < 1) {
    throw new HttpError(409, "revision_conflict", "The pending guide changed before cancellation");
  }
  await finishGuidePhotoDeletion(env, owner.id, guideID, guide.photo_count);
  return new Response(null, { status: 204 });
}

export async function activatePending(request: Request, env: AuthEnv, guideID: string): Promise<Response> {
  const owner = await requireSession(request, env);
  const revision = requiredIfMatch(request);
  if (revision !== 0) throw new HttpError(409, "revision_conflict", "Pending guides must activate at revision 0");
  const guide = await env.DB.prepare(
    "SELECT id, state, revision, guide_json, photo_count, updated_at_ms FROM sync_guides WHERE owner_id = ? AND id = ?"
  )
    .bind(owner.id, guideID)
    .first<GuideRow>();
  if (!guide) throw await guideOrNotFound(env.DB, owner.id, guideID);
  if (guide.state !== "pending" || guide.revision !== 0) throw new HttpError(409, "revision_conflict", "The guide is no longer pending");
  const photos = await photosForGuide(env.DB, owner.id, guideID);
  if (photos.length !== guide.photo_count || !(await Promise.all(photos.map(async (photo) => {
    const object = await env.GUIDE_PHOTOS.head(photo.r2_key);
    return object?.size === photo.byteCount && object.customMetadata?.sha256 === photo.sha256;
  }))).every(Boolean)) {
    throw new HttpError(409, "photos_incomplete", "Every declared photo must be uploaded before activation");
  }
  const activated = await env.DB.prepare(
    "UPDATE sync_guides SET state = 'active', revision = 1, updated_at_ms = ? WHERE owner_id = ? AND id = ? AND state = 'pending' AND revision = 0"
  )
    .bind(Date.now(), owner.id, guideID)
    .run();
  if (activated.meta.changes !== 1) throw new HttpError(409, "revision_conflict", "The guide changed before activation");
  return Response.json(await activeSnapshot(env.DB, owner.id, { ...guide, revision: 1, state: "active", updated_at_ms: Date.now() }), {
    headers: { etag: '"1"' }
  });
}

export async function updateGuide(request: Request, env: AuthEnv, guideID: string): Promise<Response> {
  const owner = await requireSession(request, env);
  const revision = requiredIfMatch(request);
  const current = await env.DB.prepare(
    "SELECT id, state, revision, guide_json, photo_count, updated_at_ms FROM sync_guides WHERE owner_id = ? AND id = ? AND state = 'active'"
  )
    .bind(owner.id, guideID)
    .first<GuideRow>();
  if (!current) throw await guideOrNotFound(env.DB, owner.id, guideID);
  const guideJSON = validateUpdateGuide(await jsonBody(request), guideID, current.photo_count);
  const result = await env.DB.prepare(
    "UPDATE sync_guides SET guide_json = ?, revision = revision + 1, updated_at_ms = ? WHERE owner_id = ? AND id = ? AND state = 'active' AND revision = ?"
  )
    .bind(guideJSON, Date.now(), owner.id, guideID, revision)
    .run();
  if (result.meta.changes !== 1) {
    const latest = await activeGuide(env.DB, owner.id, guideID);
    throw new HttpError(
      409,
      "revision_conflict",
      "The guide was updated by another writer",
      latest ? await activeSnapshot(env.DB, owner.id, latest) : undefined
    );
  }
  const updated = { ...current, guide_json: guideJSON, revision: revision + 1, updated_at_ms: Date.now() };
  return Response.json(await activeSnapshot(env.DB, owner.id, updated), { headers: { etag: `"${updated.revision}"` } });
}

export async function deleteGuide(request: Request, env: AuthEnv, guideID: string): Promise<Response> {
  const owner = await requireSession(request, env);
  const revision = requiredIfMatch(request);
  const guide = await env.DB.prepare(
    "SELECT id, state, revision, guide_json, photo_count, updated_at_ms FROM sync_guides WHERE owner_id = ? AND id = ? AND state = 'active'"
  )
    .bind(owner.id, guideID)
    .first<GuideRow>();
  if (!guide) {
    const tombstone = await env.DB.prepare("SELECT revision, photo_count FROM sync_tombstones WHERE owner_id = ? AND id = ?")
      .bind(owner.id, guideID)
      .first<{ revision: number; photo_count: number }>();
    if (tombstone?.revision === revision + 1) {
      await markGuidePhotoDeletion(env.DB, owner.id, guideID, tombstone.photo_count);
      await finishGuidePhotoDeletion(env, owner.id, guideID, tombstone.photo_count);
      return new Response(null, { status: 204 });
    }
    throw tombstone ? new HttpError(409, "guide_deleted", "The guide has already been deleted") : notFound();
  }
  const now = Date.now();
  const results = await env.DB.batch([
    env.DB
      .prepare(
        "INSERT INTO sync_tombstones (owner_id, id, revision, photo_count, deleted_at_ms) SELECT owner_id, id, revision + 1, photo_count, ? FROM sync_guides WHERE owner_id = ? AND id = ? AND state = 'active' AND revision = ?"
      )
      .bind(now, owner.id, guideID, revision),
    env.DB.prepare(
      "INSERT INTO guide_photo_deletions (owner_id, guide_id, photo_count, started_at_ms) SELECT owner_id, id, photo_count, ? FROM sync_guides WHERE owner_id = ? AND id = ? AND state = 'active' AND revision = ? ON CONFLICT (owner_id, guide_id) DO UPDATE SET photo_count = MAX(photo_count, excluded.photo_count)"
    ).bind(now, owner.id, guideID, revision),
    env.DB
      .prepare("DELETE FROM sync_guides WHERE owner_id = ? AND id = ? AND state = 'active' AND revision = ?")
      .bind(owner.id, guideID, revision)
  ]);
  if ((results[0]?.meta.changes ?? 0) < 1 || (results[2]?.meta.changes ?? 0) < 1) {
    const latest = await activeGuide(env.DB, owner.id, guideID);
    throw new HttpError(
      409,
      "revision_conflict",
      "The guide was updated by another writer",
      latest ? await activeSnapshot(env.DB, owner.id, latest) : undefined
    );
  }
  await finishGuidePhotoDeletion(env, owner.id, guideID, guide.photo_count);
  return new Response(null, { status: 204 });
}

export async function cleanupPendingGuidePhotoDeletions(env: AuthEnv, maximum = 100): Promise<void> {
  const deletions = await env.DB.prepare(
    "SELECT owner_id, guide_id, photo_count FROM guide_photo_deletions ORDER BY started_at_ms LIMIT ?"
  ).bind(maximum).all<GuidePhotoDeletionRow>();
  for (const deletion of deletions.results) {
    try {
      await deleteGuidePhotos(env.GUIDE_PHOTOS, deletion.owner_id, deletion.guide_id, deletion.photo_count);
      await env.DB.prepare("DELETE FROM guide_photo_deletions WHERE owner_id = ? AND guide_id = ?")
        .bind(deletion.owner_id, deletion.guide_id)
        .run();
    } catch {
      // The durable marker remains for the next scheduled cleanup.
    }
  }
}

export async function readPhoto(request: Request, env: AuthEnv, guideID: string, index: number): Promise<Response> {
  const owner = await requireSession(request, env);
  const photo = await env.DB.prepare(
    "SELECT p.photo_index AS \"index\", p.sha256, p.byte_count AS byteCount, p.pixel_width AS pixelWidth, p.pixel_height AS pixelHeight, p.r2_key FROM sync_guide_photos p JOIN sync_guides g ON g.owner_id = p.owner_id AND g.id = p.guide_id WHERE p.owner_id = ? AND p.guide_id = ? AND p.photo_index = ? AND g.state = 'active'"
  )
    .bind(owner.id, guideID, index)
    .first<PhotoRow>();
  if (!photo) throw await guideOrNotFound(env.DB, owner.id, guideID);
  const object = await env.GUIDE_PHOTOS.get(photo.r2_key);
  if (!object) throw notFound();
  return new Response(object.body, {
    headers: {
      "cache-control": "private, no-store",
      "content-digest": `sha-256=:${photo.sha256}:`,
      "content-length": String(object.size),
      "content-type": "image/jpeg",
      "x-content-type-options": "nosniff"
    }
  });
}

async function guideOrNotFound(db: D1Database, ownerID: string, guideID: string): Promise<HttpError> {
  const tombstone = await db.prepare("SELECT 1 FROM sync_tombstones WHERE owner_id = ? AND id = ?").bind(ownerID, guideID).first();
  return tombstone ? new HttpError(409, "guide_deleted", "The guide has been deleted") : notFound();
}

async function activeGuide(db: D1Database, ownerID: string, guideID: string): Promise<GuideRow | null> {
  return db.prepare(
    "SELECT id, state, revision, guide_json, photo_count, updated_at_ms FROM sync_guides WHERE owner_id = ? AND id = ? AND state = 'active'"
  ).bind(ownerID, guideID).first<GuideRow>();
}

async function photosForGuide(db: D1Database, ownerID: string, guideID: string): Promise<PhotoRow[]> {
  const rows = await db.prepare(
    "SELECT photo_index AS \"index\", sha256, byte_count AS byteCount, pixel_width AS pixelWidth, pixel_height AS pixelHeight, r2_key FROM sync_guide_photos WHERE owner_id = ? AND guide_id = ? ORDER BY photo_index"
  )
    .bind(ownerID, guideID)
    .all<PhotoRow>();
  return rows.results;
}

async function activeSnapshot(db: D1Database, ownerID: string, guide: GuideRow): Promise<Json> {
  const photos = await photosForGuide(db, ownerID, guide.id);
  return {
    guide: JSON.parse(guide.guide_json) as Json,
    photos: photos.map((photo) => ({
      byteCount: photo.byteCount,
      downloadPath: `/v1/sync/guides/${encodeURIComponent(guide.id)}/photos/${photo.index}`,
      index: photo.index,
      mediaType: "image/jpeg",
      pixelHeight: photo.pixelHeight,
      pixelWidth: photo.pixelWidth,
      sha256: photo.sha256
    })),
    revision: guide.revision,
    serverModifiedAt: guide.updated_at_ms,
    state: "active"
  };
}

async function markGuidePhotoDeletion(
  db: D1Database,
  ownerID: string,
  guideID: string,
  photoCount: number
): Promise<void> {
  await db.prepare(
    "INSERT INTO guide_photo_deletions (owner_id, guide_id, photo_count, started_at_ms) VALUES (?, ?, ?, ?) ON CONFLICT (owner_id, guide_id) DO UPDATE SET photo_count = MAX(photo_count, excluded.photo_count)"
  ).bind(ownerID, guideID, photoCount, Date.now()).run();
}

async function finishGuidePhotoDeletion(
  env: AuthEnv,
  ownerID: string,
  guideID: string,
  photoCount: number
): Promise<void> {
  try {
    await deleteGuidePhotos(env.GUIDE_PHOTOS, ownerID, guideID, photoCount);
    await env.DB.prepare("DELETE FROM guide_photo_deletions WHERE owner_id = ? AND guide_id = ?")
      .bind(ownerID, guideID)
      .run();
  } catch {
    throw new HttpError(503, "storage_unavailable", "The guide was deleted but its private photos need cleanup");
  }
}

function deleteGuidePhotos(bucket: R2Bucket, ownerID: string, guideID: string, photoCount: number): Promise<void> {
  return bucket.delete(Array.from({ length: photoCount }, (_, index) => photoKey(ownerID, guideID, index)));
}
