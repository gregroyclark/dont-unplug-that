import DontUnplugThatShared
import Foundation
import Testing
@testable import DontUnplugThat

private func coordinatorPhoto() -> ProcessedGuidePhoto {
    let data = Data([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9])
    return ProcessedGuidePhoto(
        data: data,
        descriptor: SyncPhotoDescriptor(
            index: 0,
            byteCount: data.count,
            sha256: PortableDigest.sha256Base64(data),
            pixelWidth: 2,
            pixelHeight: 2
        )
    )
}

private func coordinatorGuide(id: UUID = UUID(), title: String = "Rack") -> Guide {
    Guide(
        id: id,
        title: title,
        summary: "Five visible items.",
        components: (1...5).map { number in
            GuideComponent(
                displayNumber: number,
                name: "Item \(number)",
                photoIndex: 0,
                location: NormalizedCoordinate(x: 0.5, y: 0.5),
                likelyPurpose: "Routes something.",
                unpluggingImpact: "Something may stop.",
                evidenceLevel: .inferred,
                uncertaintyNotes: "The cable destination is hidden."
            )
        }
    )
}

private func coordinatorRepository() throws -> (LocalGuideRepository, URL) {
    let root = URL.temporaryDirectory.appendingPathComponent("dut-sync-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return (LocalGuideRepository(rootURL: root), root)
}

@Test("Coordinator persists the create-photo-activate revision sequence")
func coordinatorCreatesAndActivates() async throws {
    let (repository, root) = try coordinatorRepository()
    defer { try? FileManager.default.removeItem(at: root) }
    let guide = coordinatorGuide()
    let photo = coordinatorPhoto()
    _ = try repository.save(guide: guide, photos: [photo], state: .localOnly)
    let active = SyncedGuide(
        guide: guide,
        revision: 1,
        serverModifiedAt: 2,
        photos: [photo.descriptor]
    )
    let transport = MockHTTPTransport { request in
        switch (request.httpMethod ?? "GET", request.url?.path ?? "") {
        case ("GET", "/v1/sync/snapshot"):
            return HTTPResponse(
                data: try JSONEncoder().encode(GuideSyncSnapshot(guides: [], tombstones: [])),
                statusCode: 200,
                headers: [:]
            )
        case ("PUT", let path) where path.hasSuffix("/pending"):
            #expect(request.value(forHTTPHeaderField: "If-None-Match") == "*")
            let pending = try JSONDecoder().decode(PendingGuideUpload.self, from: try #require(request.httpBody))
            #expect(path.contains(pending.guide.id.uuidString))
            return HTTPResponse(data: Data("{\"revision\":0}".utf8), statusCode: 201, headers: [:])
        case ("PUT", let path) where path.hasSuffix("/photos/0"):
            #expect(request.value(forHTTPHeaderField: "Content-Digest") == "sha-256=:\(photo.descriptor.sha256):")
            return HTTPResponse(data: Data(), statusCode: 204, headers: [:])
        case ("POST", let path) where path.hasSuffix("/activate"):
            #expect(request.value(forHTTPHeaderField: "If-Match") == "\"0\"")
            return HTTPResponse(data: try JSONEncoder().encode(active), statusCode: 200, headers: [:])
        default:
            Issue.record("Unexpected sync request: \(request.httpMethod ?? "") \(request.url?.path ?? "")")
            return HTTPResponse(data: Data(), statusCode: 500, headers: [:])
        }
    }
    let coordinator = SyncCoordinator(
        repository: repository,
        client: SyncClient(
            baseURL: URL(string: "https://api.example.com")!,
            transport: transport,
            sessionStore: MemorySessionStore("token")
        ),
        accountID: "owner"
    )

    try await coordinator.sync()

    #expect(try repository.record(id: guide.id)?.syncState == .synced(1, ownerID: "owner"))
}

@Test("Coordinator stops stale local writes at a revision conflict")
func coordinatorCreatesConflict() async throws {
    let (repository, root) = try coordinatorRepository()
    defer { try? FileManager.default.removeItem(at: root) }
    let guide = coordinatorGuide()
    let photo = coordinatorPhoto()
    _ = try repository.save(guide: guide, photos: [photo], state: .dirty(1, ownerID: "owner"))
    let cloud = SyncedGuide(
        guide: coordinatorGuide(id: guide.id, title: "Changed elsewhere"),
        revision: 2,
        serverModifiedAt: 3,
        photos: [photo.descriptor]
    )
    let snapshot = GuideSyncSnapshot(guides: [cloud], tombstones: [])
    let transport = MockHTTPTransport { request in
        #expect(request.url?.path == "/v1/sync/snapshot")
        return HTTPResponse(data: try JSONEncoder().encode(snapshot), statusCode: 200, headers: [:])
    }
    let coordinator = SyncCoordinator(
        repository: repository,
        client: SyncClient(
            baseURL: URL(string: "https://api.example.com")!,
            transport: transport,
            sessionStore: MemorySessionStore("token")
        ),
        accountID: "owner"
    )

    try await coordinator.sync()

    let maybeConflicted = try repository.record(id: guide.id)
    let conflicted = try #require(maybeConflicted)
    #expect(conflicted.syncState.status == .conflicted)
    #expect(conflicted.syncState.conflict?.current?.revision == 2)
}

@Test("Coordinator never resurrects a tombstoned guide ID")
func coordinatorHonorsTombstone() async throws {
    let (repository, root) = try coordinatorRepository()
    defer { try? FileManager.default.removeItem(at: root) }
    let guide = coordinatorGuide()
    _ = try repository.save(guide: guide, photos: [coordinatorPhoto()], state: .localOnly)
    let snapshot = GuideSyncSnapshot(
        guides: [],
        tombstones: [GuideTombstone(id: guide.id, revision: 2, deletedAt: 4)]
    )
    let transport = MockHTTPTransport { request in
        #expect(request.url?.path == "/v1/sync/snapshot")
        return HTTPResponse(data: try JSONEncoder().encode(snapshot), statusCode: 200, headers: [:])
    }
    let coordinator = SyncCoordinator(
        repository: repository,
        client: SyncClient(
            baseURL: URL(string: "https://api.example.com")!,
            transport: transport,
            sessionStore: MemorySessionStore("token")
        ),
        accountID: "owner"
    )

    try await coordinator.sync()

    let maybeConflicted = try repository.record(id: guide.id)
    let conflicted = try #require(maybeConflicted)
    #expect(conflicted.syncState.status == .conflicted)
    #expect(conflicted.syncState.conflict?.kind == .deleted)
}

@Test("Coordinator cancels a queued pending upload")
func coordinatorCancelsPendingUpload() async throws {
    let (repository, root) = try coordinatorRepository()
    defer { try? FileManager.default.removeItem(at: root) }
    let guide = coordinatorGuide()
    _ = try repository.save(
        guide: guide,
        photos: [coordinatorPhoto()],
        state: .pendingUpload(ownerID: "owner")
    )
    let transport = MockHTTPTransport { request in
        switch (request.httpMethod ?? "GET", request.url?.path ?? "") {
        case ("GET", "/v1/sync/snapshot"):
            return HTTPResponse(
                data: try JSONEncoder().encode(GuideSyncSnapshot(guides: [], tombstones: [])),
                statusCode: 200,
                headers: [:]
            )
        case ("DELETE", let path) where path.hasSuffix("/pending"):
            #expect(request.value(forHTTPHeaderField: "If-Match") == "\"0\"")
            return HTTPResponse(data: Data(), statusCode: 204, headers: [:])
        default:
            Issue.record("Unexpected sync request: \(request.httpMethod ?? "") \(request.url?.path ?? "")")
            return HTTPResponse(data: Data(), statusCode: 500, headers: [:])
        }
    }
    let coordinator = SyncCoordinator(
        repository: repository,
        client: SyncClient(
            baseURL: URL(string: "https://api.example.com")!,
            transport: transport,
            sessionStore: MemorySessionStore("token")
        ),
        accountID: "owner"
    )

    try coordinator.requestDelete(id: guide.id)
    try await coordinator.sync()

    #expect(try repository.record(id: guide.id) == nil)
}

@Test("Coordinator refuses to sync another account's local records")
func coordinatorRejectsAccountMismatch() async throws {
    let (repository, root) = try coordinatorRepository()
    defer { try? FileManager.default.removeItem(at: root) }
    _ = try repository.save(
        guide: coordinatorGuide(),
        photos: [coordinatorPhoto()],
        state: .synced(1, ownerID: "owner-a")
    )
    let transport = MockHTTPTransport { _ in
        Issue.record("Account mismatch must be rejected before network access")
        return HTTPResponse(data: Data(), statusCode: 500, headers: [:])
    }
    let coordinator = SyncCoordinator(
        repository: repository,
        client: SyncClient(
            baseURL: URL(string: "https://api.example.com")!,
            transport: transport,
            sessionStore: MemorySessionStore("token")
        ),
        accountID: "owner-b"
    )

    await #expect(throws: AuthClientError.accountMismatch) {
        try await coordinator.sync()
    }
}
