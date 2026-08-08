import DontUnplugThatShared
import Foundation
import Testing
@testable import DontUnplugThat

final class MemorySessionStore: SessionStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    init(_ value: String? = nil) {
        self.value = value
    }

    func token() -> String? {
        lock.withLock { value }
    }

    func save(token: String) {
        lock.withLock { value = token }
    }

    func clear() {
        lock.withLock { value = nil }
    }
}

struct MockHTTPTransport: HTTPTransport, @unchecked Sendable {
    let handler: @Sendable (URLRequest) async throws -> HTTPResponse

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        try await handler(request)
    }
}

@Test("Production mobile builds share the deployed Worker URL")
func productionSyncURL() {
    #expect(
        SyncConfiguration.productionAPIBaseURL.absoluteString ==
            "https://dont-unplug-that-api.gregroyclark.workers.dev"
    )
}

@MainActor
@Test("Auth exchange validates PKCE callback and stores only the bearer response")
func authExchangeAndSecureStorage() async throws {
    let store = MemorySessionStore()
    let account = Account(id: "user-1", name: "Greg", email: "greg@example.com", provider: .apple)
    let transport = MockHTTPTransport { request in
        switch request.url?.path {
        case "/v1/auth/exchange":
            let exchange = try JSONDecoder().decode(MobileAuthExchangeRequest.self, from: try #require(request.httpBody))
            #expect(exchange.code == "one-time-code")
            return HTTPResponse(data: Data("{}".utf8), statusCode: 200, headers: ["set-auth-token": "session-secret"])
        case "/v1/account":
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-secret")
            return HTTPResponse(data: try JSONEncoder().encode(account), statusCode: 200, headers: [:])
        default:
            Issue.record("Unexpected request: \(request.url?.absoluteString ?? "nil")")
            return HTTPResponse(data: Data(), statusCode: 500, headers: [:])
        }
    }
    let client = AuthClient(
        baseURL: URL(string: "https://api.example.com")!,
        transport: transport,
        sessionStore: store
    )

    let signedIn = try await client.signIn(provider: .apple) { startURL in
        let components = try #require(URLComponents(url: startURL, resolvingAgainstBaseURL: false))
        let state = try #require(components.queryItems?.first { $0.name == "state" }?.value)
        let challenge = try #require(components.queryItems?.first { $0.name == "code_challenge" }?.value)
        #expect(components.queryItems?.first { $0.name == "code_challenge_method" }?.value == "S256")
        #expect(challenge.count == 43)
        return URL(string: "dontunplugthat://auth/callback?code=one-time-code&state=\(state)")!
    }

    #expect(signedIn == account)
    #expect(store.token() == "session-secret")
}

@MainActor
@Test("Auth rejects a callback with the wrong state before exchange")
func authRejectsWrongState() async {
    let transport = MockHTTPTransport { _ in
        Issue.record("A bad callback must not reach the exchange endpoint")
        return HTTPResponse(data: Data(), statusCode: 500, headers: [:])
    }
    let client = AuthClient(
        baseURL: URL(string: "https://api.example.com")!,
        transport: transport,
        sessionStore: MemorySessionStore()
    )

    await #expect(throws: AuthClientError.invalidCallback) {
        try await client.signIn(provider: .google) { _ in
            URL(string: "dontunplugthat://auth/callback?code=one-time-code&state=wrong")!
        }
    }
}
