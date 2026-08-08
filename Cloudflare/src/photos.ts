import { PhotoDescriptor } from "./contracts";
import { HttpError, base64, decodeBase64, equalBytes } from "./http";

const maxPhotoBytes = 5_242_880;

export type JpegInfo = { width: number; height: number };

export function photoKey(ownerID: string, guideID: string, index: number): string {
  return `owners/${ownerID}/guides/${guideID}/photos/${index}.jpg`;
}

export async function validatePhotoUpload(
  request: Request,
  descriptor: Omit<PhotoDescriptor, "mediaType">
): Promise<ArrayBuffer> {
  if (request.headers.get("content-type")?.split(";", 1)[0]?.trim().toLowerCase() !== "image/jpeg") {
    throw new HttpError(415, "unsupported_media_type", "Photos must be image/jpeg");
  }
  const length = request.headers.get("content-length");
  if (!length || !/^[0-9]+$/.test(length)) {
    throw new HttpError(400, "content_length_required", "Content-Length is required for photo uploads");
  }
  if (Number(length) > maxPhotoBytes) throw new HttpError(413, "photo_too_large", "Photos must not exceed 5 MiB");
  const bytes = await readAtMost(request, maxPhotoBytes);
  if (bytes.byteLength !== Number(length) || bytes.byteLength > maxPhotoBytes) {
    throw new HttpError(413, "photo_too_large", "Photos must not exceed 5 MiB");
  }
  if (bytes.byteLength !== descriptor.byteCount) {
    throw new HttpError(422, "photo_size_mismatch", "The photo does not match its descriptor");
  }
  const info = inspectJpeg(bytes);
  if (info.width !== descriptor.pixelWidth || info.height !== descriptor.pixelHeight) {
    throw new HttpError(422, "photo_dimension_mismatch", "The photo dimensions do not match its descriptor");
  }
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  const declaredDigest = parseContentDigest(request.headers.get("content-digest"));
  const descriptorDigest = decodeBase64(descriptor.sha256);
  if (!declaredDigest || !descriptorDigest || !equalBytes(digest, declaredDigest) || !equalBytes(digest, descriptorDigest)) {
    throw new HttpError(422, "photo_digest_mismatch", "The photo digest does not match its descriptor");
  }
  return bytes;
}

export function inspectJpeg(bytes: ArrayBufferLike): JpegInfo {
  const data = new Uint8Array(bytes);
  if (data.length < 4 || data[0] !== 0xff || data[1] !== 0xd8) {
    throw new HttpError(415, "unsupported_media_type", "The payload is not a JPEG");
  }
  let position = 2;
  let inScan = false;
  let width: number | undefined;
  let height: number | undefined;
  let ended = false;
  while (position < data.length) {
    if (data[position] !== 0xff) {
      if (inScan) {
        position += 1;
        continue;
      }
      throw new HttpError(415, "invalid_jpeg", "The JPEG marker stream is invalid");
    }
    while (position < data.length && data[position] === 0xff) position += 1;
    if (position >= data.length) break;
    const marker = data[position]!;
    position += 1;
    if (inScan && marker === 0x00) continue;
    if (inScan && marker >= 0xd0 && marker <= 0xd7) continue;
    if (marker === 0xd9) {
      ended = true;
      break;
    }
    if (marker === 0xd8) continue;
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
    if (position + 2 > data.length) throw new HttpError(415, "invalid_jpeg", "The JPEG segment is truncated");
    const length = (data[position]! << 8) | data[position + 1]!;
    if (length < 2 || position + length > data.length) throw new HttpError(415, "invalid_jpeg", "The JPEG segment is invalid");
    const payloadStart = position + 2;
    const payloadEnd = position + length;
    if (marker >= 0xe0 && marker <= 0xef) validateAppSegment(marker, data.subarray(payloadStart, payloadEnd));
    if (marker === 0xfe) throw new HttpError(422, "photo_metadata_forbidden", "JPEG comments are not allowed");
    if (isStartOfFrame(marker)) {
      if (length < 8) throw new HttpError(415, "invalid_jpeg", "The JPEG frame is invalid");
      height = (data[payloadStart + 1]! << 8) | data[payloadStart + 2]!;
      width = (data[payloadStart + 3]! << 8) | data[payloadStart + 4]!;
      if (!width || !height || Math.max(width, height) > 2048) {
        throw new HttpError(422, "photo_dimension_mismatch", "JPEG dimensions must not exceed 2048 pixels");
      }
    }
    position = payloadEnd;
    inScan = marker === 0xda;
  }
  if (!ended || !width || !height || position !== data.length) {
    throw new HttpError(415, "invalid_jpeg", "The JPEG is incomplete");
  }
  return { width, height };
}

export function contentDigest(bytes: ArrayBuffer): string {
  return `sha-256=:${base64(bytes)}:`;
}

function validateAppSegment(marker: number, payload: Uint8Array): void {
  if (marker !== 0xe0 || !startsWith(payload, [0x4a, 0x46, 0x49, 0x46, 0]) || payload.length < 14) {
    throw new HttpError(422, "photo_metadata_forbidden", "JPEG metadata is not allowed");
  }
  const thumbnailLength = payload[12]! * payload[13]! * 3;
  if (payload.length !== 14 + thumbnailLength) {
    throw new HttpError(422, "photo_metadata_forbidden", "JPEG metadata is not allowed");
  }
}

function startsWith(value: Uint8Array, prefix: number[]): boolean {
  return prefix.every((byte, index) => value[index] === byte);
}

function isStartOfFrame(marker: number): boolean {
  return (marker >= 0xc0 && marker <= 0xc3) || (marker >= 0xc5 && marker <= 0xc7) || (marker >= 0xc9 && marker <= 0xcb) || (marker >= 0xcd && marker <= 0xcf);
}

function parseContentDigest(value: string | null): Uint8Array | null {
  const matched = /^sha-256=:(.+):$/i.exec(value ?? "");
  return matched ? decodeBase64(matched[1]!) : null;
}

async function readAtMost(request: Request, maximumBytes: number): Promise<ArrayBuffer> {
  if (!request.body) return new ArrayBuffer(0);
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      size += next.value.byteLength;
      if (size > maximumBytes) {
        await reader.cancel();
        throw new HttpError(413, "photo_too_large", "Photos must not exceed 5 MiB");
      }
      chunks.push(next.value);
    }
  } finally {
    reader.releaseLock();
  }
  const complete = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    complete.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return complete.buffer;
}
