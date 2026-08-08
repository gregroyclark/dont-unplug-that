import { describe, expect, it } from "vitest";

import { inspectJpeg, validatePhotoUpload } from "../src/photos";
import { descriptor, digestHeader, validJpeg } from "./support";

describe("private photo validation", () => {
  it("accepts a metadata-free JPEG and reads its dimensions", () => {
    expect(inspectJpeg(validJpeg().buffer)).toEqual({ height: 2, width: 3 });
  });

  it("rejects wrong media type, digest, dimensions, and APP metadata", async () => {
    const image = validJpeg();
    const photo = await descriptor(0, image);
    await expect(validatePhotoUpload(new Request("https://api.example.test", {
      body: image,
      headers: { "content-length": String(image.byteLength), "content-type": "image/png" },
      method: "PUT"
    }), photo)).rejects.toMatchObject({ status: 415 });
    await expect(validatePhotoUpload(new Request("https://api.example.test", {
      body: image,
      headers: { "content-digest": "sha-256=:bad:", "content-length": String(image.byteLength), "content-type": "image/jpeg" },
      method: "PUT"
    }), photo)).rejects.toMatchObject({ code: "photo_digest_mismatch" });
    const metadata = new Uint8Array([...image.slice(0, 2), 0xff, 0xe1, 0x00, 0x08, 0x45, 0x78, 0x69, 0x66, 0x00, 0x00, ...image.slice(2)]);
    expect(() => inspectJpeg(metadata.buffer)).toThrow(/metadata/i);
    const badDimensions = { ...photo, pixelWidth: 4 };
    await expect(validatePhotoUpload(new Request("https://api.example.test", {
      body: image,
      headers: { "content-digest": await digestHeader(image), "content-length": String(image.byteLength), "content-type": "image/jpeg" },
      method: "PUT"
    }), badDimensions)).rejects.toMatchObject({ code: "photo_dimension_mismatch" });
    await expect(validatePhotoUpload(new Request("https://api.example.test", {
      body: image,
      headers: { "content-digest": await digestHeader(image), "content-length": "5242881", "content-type": "image/jpeg" },
      method: "PUT"
    }), photo)).rejects.toMatchObject({ status: 413 });
  });
});
