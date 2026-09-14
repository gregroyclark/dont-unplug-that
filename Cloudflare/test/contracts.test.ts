import { describe, expect, it } from "vitest";
import { validatePendingGuide, validateUpdateGuide } from "../src/contracts";

const guideID = "11111111-1111-4111-8111-111111111111";
function guide(count: number) {
  return { id: guideID, title: "Setup", summary: "Visible connections", components:
    Array.from({ length: count }, (_, index) => ({
      id: `item-${index}`, displayNumber: index + 1, name: "Cable", kind: "connection",
      photoIndex: 0, location: { x: 0.5, y: 0.5 }, likelyPurpose: "Unknown connection",
      unpluggingImpact: "May interrupt service", evidenceLevel: "unclear",
      uncertaintyNotes: "Destination is hidden"
    })) };
}
const photo = { index: 0, mediaType: "image/jpeg", sha256: "A".repeat(43) + "=",
  byteCount: 1024, pixelWidth: 1600, pixelHeight: 1200 };

describe("analysis guide count contract", () => {
  it.each([1, 4, 5, 12])("accepts %i grounded items for creation and updates", (count) => {
    const value = guide(count);
    expect(validatePendingGuide({ guide: value, photos: [photo] }, guideID).guide).toEqual(value);
    expect(JSON.parse(validateUpdateGuide({ guide: value }, guideID, 1))).toEqual(value);
  });
  it.each([0, 13])("rejects %i items for creation and updates", (count) => {
    const value = guide(count);
    expect(() => validatePendingGuide({ guide: value, photos: [photo] }, guideID)).toThrow();
    expect(() => validateUpdateGuide({ guide: value }, guideID, 1)).toThrow();
  });
});
