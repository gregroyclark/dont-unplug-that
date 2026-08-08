import DontUnplugThatShared
import Foundation

struct SyncClient: Sendable {
    let baseURL: URL
    let transport: any HTTPTransport
    let sessionStore: any SessionStoring

    init(
        baseURL: URL,
        transport: any HTTPTransport = URLSessionTransport(),
        sessionStore: any SessionStoring = SecureSessionStore()
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.sessionStore = sessionStore
    }

    func snapshot() async throws -> GuideSyncSnapshot {
        let response = try await send(path: "v1/sync/snapshot")
        let snapshot: GuideSyncSnapshot = try decode(response)
        try snapshot.validate()
        return snapshot
    }

    func createPending(_ record: LocalGuideRecord) async throws {
        var request = try request(path: guidePath(record.id) + "/pending")
        request.httpMethod = "PUT"
        request.setValue("*", forHTTPHeaderField: "If-None-Match")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            PendingGuideUpload(guide: record.guide, photos: record.photos)
        )
        let response = try await transport.send(request)
        if response.statusCode == 409,
           let envelope = try? JSONDecoder().decode(GuideSyncErrorEnvelope.self, from: response.data),
           envelope.error.code == "guide_exists" {
            // A retry after an interrupted upload can safely continue with the
            // digest-checked photo endpoints and activation precondition.
            return
        }
        guard response.statusCode == 201 else { try throwAPIError(response) }
    }

    func uploadPhoto(guideID: UUID, photo: SyncPhotoDescriptor, data: Data) async throws {
        guard data.count == photo.byteCount,
              PortableDigest.sha256Base64(data) == photo.sha256 else {
            throw APIClientError.invalidResponse
        }
        var request = try request(path: guidePath(guideID) + "/photos/\(photo.index)")
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("sha-256=:\(photo.sha256):", forHTTPHeaderField: "Content-Digest")
        request.httpBody = data
        let response = try await transport.send(request)
        guard response.statusCode == 204 else { try throwAPIError(response) }
    }

    func activate(guideID: UUID) async throws -> SyncedGuide {
        var request = try request(path: guidePath(guideID) + "/activate")
        request.httpMethod = "POST"
        request.setValue("\"0\"", forHTTPHeaderField: "If-Match")
        return try decode(await transport.send(request))
    }

    func update(_ record: LocalGuideRecord, baseRevision: Int) async throws -> SyncedGuide {
        var request = try request(path: guidePath(record.id))
        request.httpMethod = "PUT"
        request.setValue("\"\(baseRevision)\"", forHTTPHeaderField: "If-Match")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GuideUpdate(guide: record.guide))
        return try decode(await transport.send(request))
    }

    func delete(guideID: UUID, baseRevision: Int) async throws {
        var request = try request(path: guidePath(guideID))
        request.httpMethod = "DELETE"
        request.setValue("\"\(baseRevision)\"", forHTTPHeaderField: "If-Match")
        let response = try await transport.send(request)
        guard response.statusCode == 204 else { try throwAPIError(response) }
    }

    func cancelPending(guideID: UUID) async throws {
        var request = try request(path: guidePath(guideID) + "/pending")
        request.httpMethod = "DELETE"
        request.setValue("\"0\"", forHTTPHeaderField: "If-Match")
        let response = try await transport.send(request)
        guard response.statusCode == 204 else { try throwAPIError(response) }
    }

    func downloadPhoto(path: String, expected: SyncPhotoDescriptor) async throws -> Data {
        let response = try await send(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        guard response.statusCode == 200,
              response.data.count == expected.byteCount,
              PortableDigest.sha256Base64(response.data) == expected.sha256 else {
            if response.statusCode != 200 { try throwAPIError(response) }
            throw APIClientError.invalidResponse
        }
        return response.data
    }

    private func send(path: String) async throws -> HTTPResponse {
        let response = try await transport.send(try request(path: path))
        guard (200..<300).contains(response.statusCode) else { try throwAPIError(response) }
        return response
    }

    private func request(path: String) throws -> URLRequest {
        guard let token = try sessionStore.token(), !token.isEmpty else {
            throw APIClientError.server(status: 401, code: "unauthenticated", message: "Turn on Sync to continue.")
        }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        return request
    }

    private func guidePath(_ id: UUID) -> String {
        // JSONEncoder uses UUID.uuidString, so the route ID must use the same
        // spelling for the Worker's exact guide.id ownership check.
        "v1/sync/guides/\(id.uuidString)"
    }

    private func decode<T: Decodable>(_ response: HTTPResponse) throws -> T {
        guard (200..<300).contains(response.statusCode) else { try throwAPIError(response) }
        guard let value = try? JSONDecoder().decode(T.self, from: response.data) else {
            throw APIClientError.invalidResponse
        }
        return value
    }

    private func throwAPIError(_ response: HTTPResponse) throws -> Never {
        guard let envelope = try? JSONDecoder().decode(GuideSyncErrorEnvelope.self, from: response.data) else {
            throw APIClientError.server(
                status: response.statusCode,
                code: "http_error",
                message: "Sync failed (\(response.statusCode))."
            )
        }
        if envelope.error.code == "guide_deleted" {
            throw APIClientError.deleted
        }
        if envelope.error.code == "revision_conflict" || envelope.error.code == "guide_exists" {
            throw APIClientError.conflict(current: envelope.error.current)
        }
        throw APIClientError.server(
            status: response.statusCode,
            code: envelope.error.code,
            message: envelope.error.message
        )
    }
}
