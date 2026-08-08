import Foundation
import Testing
@testable import DontUnplugThatShared

private let digest = Data(repeating: 7, count: 32).base64EncodedString()

private func photo(index: Int) -> SyncPhotoDescriptor {
    SyncPhotoDescriptor(
        index: index,
        byteCount: 1_024,
        sha256: digest,
        pixelWidth: 1_600,
        pixelHeight: 1_200
    )
}

private func guide(photoCount: Int = 1) -> Guide {
    let item = GuideComponent(
        displayNumber: 1,
        name: "Power strip",
        photoIndex: photoCount - 1,
        location: NormalizedCoordinate(x: 0.5, y: 0.5),
        likelyPurpose: "Distributes power.",
        unpluggingImpact: "Connected equipment may turn off.",
        evidenceLevel: .observed,
        uncertaintyNotes: "The upstream feed is not visible."
    )
    return Guide(
        title: "Rack",
        summary: "A small equipment rack.",
        components: (1...5).map { number in
            var component = item
            component.id = UUID()
            component.displayNumber = number
            return component
        }
    )
}

@Test("Pending guide validates a contiguous JPEG manifest")
func validatesPendingGuide() throws {
    let upload = PendingGuideUpload(
        guide: guide(photoCount: 2),
        photos: [photo(index: 0), photo(index: 1)]
    )

    try upload.validate()
    let encoded = try JSONEncoder().encode(upload)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    let photos = try #require(object["photos"] as? [[String: Any]])
    #expect(photos.first?["mediaType"] as? String == "image/jpeg")
    let decoded = try JSONDecoder().decode(
        PendingGuideUpload.self,
        from: encoded
    )
    #expect(decoded == upload)
}

@Test("Guide validation rejects missing and reordered photos")
func rejectsInvalidPhotoManifests() {
    #expect(throws: GuideSyncValidationError.invalidPhotoCount) {
        try PendingGuideUpload(guide: guide(), photos: []).validate()
    }
    #expect(throws: GuideSyncValidationError.invalidPhotoIndex) {
        try PendingGuideUpload(guide: guide(), photos: [photo(index: 1)]).validate()
    }

}

@Test("Guide validation rejects unsafe photo metadata and references")
func rejectsInvalidPhotoMetadata() {
    var oversized = photo(index: 0)
    oversized.byteCount = maximumGuidePhotoByteCount + 1
    #expect(throws: GuideSyncValidationError.invalidPhotoSize) {
        try PendingGuideUpload(guide: guide(), photos: [oversized]).validate()
    }

    var invalidDigest = photo(index: 0)
    invalidDigest.sha256 = "not-a-digest"
    #expect(throws: GuideSyncValidationError.invalidPhotoDigest) {
        try PendingGuideUpload(guide: guide(), photos: [invalidDigest]).validate()
    }

    var unsupportedMediaType = photo(index: 0)
    unsupportedMediaType.mediaType = .png
    #expect(throws: GuideSyncValidationError.invalidPhotoMediaType) {
        try PendingGuideUpload(guide: guide(), photos: [unsupportedMediaType]).validate()
    }

    var invalidGuide = guide()
    invalidGuide.components[0].photoIndex = 2
    #expect(throws: GuideSyncValidationError.invalidGuide) {
        try PendingGuideUpload(guide: invalidGuide, photos: [photo(index: 0)]).validate()
    }
}

@Test("Snapshot and tombstones require positive revisions")
func validatesSnapshotRevisions() throws {
    let synced = SyncedGuide(
        guide: guide(),
        revision: 1,
        serverModifiedAt: 1_700_000_000_000,
        photos: [photo(index: 0)]
    )
    let snapshot = GuideSyncSnapshot(
        guides: [synced],
        tombstones: [GuideTombstone(id: UUID(), revision: 2, deletedAt: 1_700_000_000_001)]
    )
    try snapshot.validate()

    var invalid = synced
    invalid.revision = 0
    #expect(throws: GuideSyncValidationError.invalidRevision) {
        try invalid.validate()
    }
}
