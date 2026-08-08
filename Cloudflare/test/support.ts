import { env } from "cloudflare:test";
import type { AuthEnv } from "../src/auth";
import type { PhotoDescriptor } from "../src/contracts";
import type { Json } from "../src/http";

export const workerEnv = env as AuthEnv;

export async function seedOwner(id: string, token: string, provider = "google"): Promise<void> {
  const now = new Date().toISOString();
  await workerEnv.DB.prepare(
    'INSERT INTO "user" ("id", "name", "email", "emailVerified", "createdAt", "updatedAt") VALUES (?, ?, ?, 1, ?, ?)'
  )
    .bind(id, `Owner ${id}`, `${id}@example.test`, now, now)
    .run();
  await workerEnv.DB.prepare(
    'INSERT INTO "session" ("id", "expiresAt", "token", "createdAt", "updatedAt", "userId") VALUES (?, ?, ?, ?, ?, ?)'
  )
    .bind(`${id}-session`, new Date(Date.now() + 3_600_000).toISOString(), token, now, now, id)
    .run();
  await workerEnv.DB.prepare(
    'INSERT INTO "account" ("id", "accountId", "providerId", "userId", "accessToken", "createdAt", "updatedAt") VALUES (?, ?, ?, ?, ?, ?, ?)'
  )
    .bind(`${id}-account`, `${id}-provider`, provider, id, `${id}-access-token`, now, now)
    .run();
}

export function request(path: string, token: string, init: RequestInit = {}): Request {
  const headers = new Headers(init.headers);
  headers.set("authorization", `Bearer ${token}`);
  return new Request(`https://api.example.test${path}`, { ...init, headers });
}

export function guide(id: string, photoCount = 1): Json {
  return {
    components: Array.from({ length: 5 }, (_, index) => ({
      displayNumber: index + 1,
      evidenceLevel: "observed",
      id: `component-${index}`,
      kind: "component",
      likelyPurpose: "Distributes power to connected equipment.",
      location: { x: 0.5, y: 0.5 },
      name: `Component ${index + 1}`,
      photoIndex: index % photoCount,
      safetyWarning: null,
      uncertaintyNotes: "The far end is outside the photo.",
      unpluggingImpact: "Connected equipment may turn off."
    })),
    id,
    summary: "A short guide",
    title: "Fixture guide"
  };
}

export function validJpeg(width = 3, height = 2): Uint8Array {
  return new Uint8Array([
    0xff, 0xd8,
    0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
    0xff, 0xdb, 0x00, 0x43, 0x00, ...Array(64).fill(1),
    0xff, 0xc0, 0x00, 0x11, 0x08, height >> 8, height & 0xff, width >> 8, width & 0xff, 0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
    0xff, 0xda, 0x00, 0x0c, 0x03, 0x01, 0x00, 0x02, 0x11, 0x03, 0x11, 0x00, 0x3f, 0x00,
    0x00, 0xff, 0xd9
  ]);
}

export async function descriptor(index = 0, bytes = validJpeg()): Promise<PhotoDescriptor> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  let binary = "";
  for (const value of new Uint8Array(digest)) binary += String.fromCharCode(value);
  return { byteCount: bytes.byteLength, index, mediaType: "image/jpeg", pixelHeight: 2, pixelWidth: 3, sha256: btoa(binary) };
}

export async function digestHeader(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  let binary = "";
  for (const value of new Uint8Array(digest)) binary += String.fromCharCode(value);
  return `sha-256=:${btoa(binary)}:`;
}
