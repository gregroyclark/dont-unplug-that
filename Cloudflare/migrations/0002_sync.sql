-- Worker-owned sync metadata.  Better Auth owns the tables created in 0001.
PRAGMA foreign_keys = ON;

CREATE TABLE auth_handoff (
  id TEXT PRIMARY KEY,
  callback_state TEXT NOT NULL,
  state_hash TEXT NOT NULL UNIQUE,
  code_hash TEXT UNIQUE,
  provider TEXT NOT NULL CHECK (provider IN ('apple', 'google')),
  client_hash TEXT NOT NULL,
  pkce_challenge TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'ready', 'consumed')),
  user_id TEXT REFERENCES "user" ("id") ON DELETE CASCADE,
  created_at_ms INTEGER NOT NULL,
  expires_at_ms INTEGER NOT NULL,
  consumed_at_ms INTEGER
);

CREATE INDEX auth_handoff_expiry_idx ON auth_handoff (expires_at_ms);
CREATE INDEX auth_handoff_client_expiry_idx ON auth_handoff (client_hash, expires_at_ms);

-- Deliberately has no user foreign key: after the Better Auth user row is
-- removed, scheduled R2 cleanup must retain a durable retry record.
CREATE TABLE account_deletions (
  user_id TEXT PRIMARY KEY,
  provider_revoked INTEGER NOT NULL DEFAULT 0 CHECK (provider_revoked IN (0, 1)),
  started_at_ms INTEGER NOT NULL
);

-- Also survives guide/account row deletion so failed private-object cleanup
-- can be retried by the scheduled Worker.
CREATE TABLE guide_photo_deletions (
  owner_id TEXT NOT NULL,
  guide_id TEXT NOT NULL,
  photo_count INTEGER NOT NULL CHECK (photo_count BETWEEN 1 AND 3),
  started_at_ms INTEGER NOT NULL,
  PRIMARY KEY (owner_id, guide_id)
);

CREATE TABLE sync_guides (
  owner_id TEXT NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  id TEXT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('pending', 'active')),
  revision INTEGER NOT NULL CHECK (revision >= 0),
  guide_json TEXT NOT NULL,
  photo_count INTEGER NOT NULL CHECK (photo_count BETWEEN 1 AND 3),
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY (owner_id, id)
);

CREATE INDEX sync_guides_owner_state_idx ON sync_guides (owner_id, state, updated_at_ms DESC);

CREATE TABLE sync_guide_photos (
  owner_id TEXT NOT NULL,
  guide_id TEXT NOT NULL,
  photo_index INTEGER NOT NULL CHECK (photo_index >= 0 AND photo_index <= 2),
  sha256 TEXT NOT NULL,
  byte_count INTEGER NOT NULL CHECK (byte_count > 0 AND byte_count <= 5242880),
  pixel_width INTEGER NOT NULL CHECK (pixel_width > 0 AND pixel_width <= 2048),
  pixel_height INTEGER NOT NULL CHECK (pixel_height > 0 AND pixel_height <= 2048),
  r2_key TEXT NOT NULL,
  PRIMARY KEY (owner_id, guide_id, photo_index),
  FOREIGN KEY (owner_id, guide_id) REFERENCES sync_guides (owner_id, id) ON DELETE CASCADE
);

CREATE TABLE sync_tombstones (
  owner_id TEXT NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  id TEXT NOT NULL,
  revision INTEGER NOT NULL CHECK (revision >= 1),
  photo_count INTEGER NOT NULL CHECK (photo_count BETWEEN 1 AND 3),
  deleted_at_ms INTEGER NOT NULL,
  PRIMARY KEY (owner_id, id)
);

CREATE INDEX sync_tombstones_owner_deleted_idx ON sync_tombstones (owner_id, deleted_at_ms DESC);
