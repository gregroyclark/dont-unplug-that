import DontUnplugThatShared
import Foundation

struct HTTPResponse: Sendable {
    let data: Data
    let statusCode: Int
    let headers: [String: String]

    func header(_ name: String) -> String? {
        let lowered = name.lowercased()
        return headers.first { $0.key.lowercased() == lowered }?.value
    }
}

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPResponse
}

struct URLSessionTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            headers[String(describing: key)] = String(describing: value)
        }
        return HTTPResponse(data: data, statusCode: response.statusCode, headers: headers)
    }
}

enum APIClientError: LocalizedError, Equatable {
    case invalidResponse
    case server(status: Int, code: String, message: String)
    case conflict(current: SyncedGuide?)
    case deleted

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The sync service returned an invalid response."
        case .server(_, _, let message): message
        case .conflict: "This guide changed on another device."
        case .deleted: "This guide was deleted on another device."
        }
    }
}
