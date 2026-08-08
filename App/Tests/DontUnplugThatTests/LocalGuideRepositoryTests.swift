import DontUnplugThatShared
import Foundation
import Testing
@testable import DontUnplugThat

private func repositoryGuide(id: UUID = UUID(), title: String = "Studio rack") -> Guide {
    Guide(
        id: id,
        title: title,
        summary: "A small connected setup.",
        components: (1...5).map { number in
            GuideComponent(
                displayNumber: number,
                name: "Item \(number)",
                photoIndex: 0,
                location: NormalizedCoordinate(x: 0.5, y: 0.5),
                likelyPurpose: "Routes a signal.",
                unpluggingImpact: "The signal may stop.",
                evidenceLevel: .observed,
                uncertaintyNotes: "The destination is not visible."
            )
        }
    )
}

private func repositoryPhoto(index: Int = 0) -> ProcessedGuidePhoto {
    let data = Data([0xff, 0xd8, 0xff, 0xd9])
    return ProcessedGuidePhoto(
        data: data,
        descriptor: SyncPhotoDescriptor(
            index: index,
            byteCount: data.count,
            sha256: PortableDigest.sha256Base64(data),
            pixelWidth: 1,
            pixelHeight: 1
        )
    )
}

@Test("Local guide repository atomically round-trips guide and photo data")
func localRepositoryRoundTrip() throws {
    let root = URL.temporaryDirectory.appendingPathComponent("dut-repository-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = LocalGuideRepository(rootURL: root)
    let guide = repositoryGuide()

    let saved = try repository.save(
        guide: guide,
        photos: [repositoryPhoto()],
        state: .localOnly
    )
    let maybeLoaded = try repository.record(id: guide.id)
    let loaded = try #require(maybeLoaded)

    #expect(loaded == saved)
    #expect(try Data(contentsOf: repository.photoURL(guideID: guide.id, index: 0)) == repositoryPhoto().data)
    #expect(try repository.all().map(\.id) == [guide.id])
}

@Test("A rejected replacement leaves the existing guide intact")
func rejectedReplacementPreservesGuide() throws {
    let root = URL.temporaryDirectory.appendingPathComponent("dut-repository-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = LocalGuideRepository(rootURL: root)
    let guide = repositoryGuide()
    _ = try repository.save(guide: guide, photos: [repositoryPhoto()], state: .localOnly)

    #expect(throws: GuideSyncValidationError.invalidPhotoCount) {
        try repository.save(guide: guide, photos: [], state: .localOnly)
    }
    #expect(try repository.record(id: guide.id)?.guide == guide)
}

@Test("Account removal keeps local guides and clears their sync state")
func accountRemovalKeepsLocalGuides() throws {
    let root = URL.temporaryDirectory.appendingPathComponent("dut-repository-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = LocalGuideRepository(rootURL: root)
    let guide = repositoryGuide()
    _ = try repository.save(guide: guide, photos: [repositoryPhoto()], state: .synced(4, ownerID: "owner"))

    try repository.makeAllLocalOnly()

    #expect(try repository.record(id: guide.id)?.syncState == .localOnly)
    #expect(FileManager.default.fileExists(atPath: repository.photoURL(guideID: guide.id, index: 0).path))
}
