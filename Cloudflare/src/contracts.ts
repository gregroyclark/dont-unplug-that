import { HttpError, Json, record, stringField } from "./http";

export type PhotoDescriptor = {
  index: number;
  mediaType: "image/jpeg";
  sha256: string;
  byteCount: number;
  pixelWidth: number;
  pixelHeight: number;
};

export type PendingGuide = {
  guide: { [key: string]: Json };
  photos: PhotoDescriptor[];
  encodedGuide: string;
};

const maxGuideBytes = 131_072;

export function validatePendingGuide(value: Json, guideID: string): PendingGuide {
  const body = record(value);
  const guide = record(body.guide);
  const photosValue = body.photos;
  if (!Array.isArray(photosValue) || photosValue.length < 1 || photosValue.length > 3) {
    throw new HttpError(400, "invalid_photos", "Guides require between one and three photos");
  }
  const photos = photosValue.map((photo, index) => validateDescriptor(photo, index));
  validateGuide(guide, guideID, photos.length);
  const encodedGuide = JSON.stringify(guide);
  if (new TextEncoder().encode(encodedGuide).byteLength > maxGuideBytes) {
    throw new HttpError(413, "guide_too_large", "The guide JSON exceeds 128 KiB");
  }
  return { guide, photos, encodedGuide };
}

export function validateUpdateGuide(value: Json, guideID: string, photoCount: number): string {
  const body = record(value);
  const guide = record(body.guide);
  validateGuide(guide, guideID, photoCount);
  const encodedGuide = JSON.stringify(guide);
  if (new TextEncoder().encode(encodedGuide).byteLength > maxGuideBytes) {
    throw new HttpError(413, "guide_too_large", "The guide JSON exceeds 128 KiB");
  }
  return encodedGuide;
}

function validateDescriptor(value: Json, expectedIndex: number): PhotoDescriptor {
  const descriptor = record(value);
  const index = numberField(descriptor.index);
  const byteCount = numberField(descriptor.byteCount);
  const pixelWidth = numberField(descriptor.pixelWidth);
  const pixelHeight = numberField(descriptor.pixelHeight);
  if (descriptor.mediaType !== "image/jpeg") {
    throw new HttpError(400, "invalid_photos", "Photo mediaType must be image/jpeg");
  }
  if (index !== expectedIndex || !Number.isInteger(index)) {
    throw new HttpError(400, "invalid_photos", "Photo indices must be contiguous and start at zero");
  }
  if (!Number.isInteger(byteCount) || byteCount <= 0 || byteCount > 5_242_880) {
    throw new HttpError(400, "invalid_photos", "Photo byteCount must be between 1 and 5242880");
  }
  if (
    !Number.isInteger(pixelWidth) ||
    !Number.isInteger(pixelHeight) ||
    pixelWidth <= 0 ||
    pixelHeight <= 0 ||
    Math.max(pixelWidth, pixelHeight) > 2048
  ) {
    throw new HttpError(400, "invalid_photos", "Photo dimensions must not exceed 2048 pixels");
  }
  const sha = stringField(descriptor.sha256, "photos[].sha256");
  if (!/^[A-Za-z0-9+/]{43}=$/.test(sha)) {
    throw new HttpError(400, "invalid_photos", "Photo sha256 must be base64 SHA-256");
  }
  return { index, mediaType: "image/jpeg", sha256: sha, byteCount, pixelWidth, pixelHeight };
}

function validateGuide(guide: { [key: string]: Json }, guideID: string, photoCount: number): void {
  if (guide.id !== guideID) throw new HttpError(400, "guide_id_mismatch", "guide.id must match the route ID");
  requiredText(guide.title, "guide.title", 200);
  requiredText(guide.summary, "guide.summary", 4_000);
  const components = guide.components;
  if (!Array.isArray(components) || components.length < 5 || components.length > 12) {
    throw new HttpError(400, "invalid_guide", "Guides require between five and twelve components");
  }
  const displayNumbers: number[] = [];
  for (const component of components) {
    const item = record(component, "invalid_guide");
    requiredText(item.id, "components[].id", 100);
    requiredText(item.name, "components[].name", 200);
    requiredText(item.likelyPurpose, "components[].likelyPurpose", 4_000);
    requiredText(item.unpluggingImpact, "components[].unpluggingImpact", 4_000);
    requiredText(item.uncertaintyNotes, "components[].uncertaintyNotes", 4_000);
    if (item.safetyWarning !== null && item.safetyWarning !== undefined) {
      requiredText(item.safetyWarning, "components[].safetyWarning", 4_000);
    }
    if (item.kind !== "component" && item.kind !== "connection") {
      throw new HttpError(400, "invalid_guide", "Every component kind must be component or connection");
    }
    if (item.evidenceLevel !== "observed" && item.evidenceLevel !== "inferred" && item.evidenceLevel !== "unclear") {
      throw new HttpError(400, "invalid_guide", "Every component needs a valid evidenceLevel");
    }
    const displayNumber = numberField(item.displayNumber);
    if (!Number.isInteger(displayNumber) || displayNumber < 1) {
      throw new HttpError(400, "invalid_guide", "Every component needs a positive displayNumber");
    }
    displayNumbers.push(displayNumber);
    const photoIndex = numberField(item.photoIndex);
    if (!Number.isInteger(photoIndex) || photoIndex < 0 || photoIndex >= photoCount) {
      throw new HttpError(400, "invalid_guide", "Every component photoIndex must reference an uploaded photo");
    }
    const location = record(item.location, "invalid_guide");
    if (!normalized(location.x) || !normalized(location.y)) {
      throw new HttpError(400, "invalid_guide", "Every component location must use normalized coordinates");
    }
  }
  if (new Set(displayNumbers).size !== components.length ||
      [...displayNumbers].sort((left, right) => left - right).some((number, index) => number !== index + 1)) {
    throw new HttpError(400, "invalid_guide", "Component display numbers must be contiguous and unique");
  }
}

function requiredText(value: Json | undefined, name: string, maximumLength: number): string {
  if (typeof value !== "string" || !value.trim() || value.length > maximumLength) {
    throw new HttpError(400, "invalid_guide", `${name} must be non-empty and at most ${maximumLength} characters`);
  }
  return value;
}

function normalized(value: Json | undefined): boolean {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 1;
}

function numberField(value: Json | undefined): number {
  return typeof value === "number" ? value : Number.NaN;
}
