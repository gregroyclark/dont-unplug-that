import DontUnplugThatShared
import Foundation

enum AuthClientError: LocalizedError, Equatable {
    case syncUnavailable
    case invalidCallback
    case invalidResponse
    case accountMismatch
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .syncUnavailable: "Sync is not configured in this build."
        case .invalidCallback: "The sign-in callback was invalid. Please try again."
        case .invalidResponse: "The sign-in server returned an invalid response."
        case .accountMismatch: "These guides are linked to a different account. Sign back into that account or delete it before switching."
        case .server(_, let message): message
        }
    }
}

struct AuthClient: Sendable {
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

    @MainActor
    func signIn(
        provider: AuthProvider,
        authenticate: (URL) async throws -> URL
    ) async throws -> Account {
        let pkce = PKCEPair.make()
        let state = PKCEPair.randomState()
        var components = URLComponents(
            url: baseURL.appendingPathComponent("v1/auth/start"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "provider", value: provider.rawValue),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let startURL = components?.url else {
            throw AuthClientError.invalidResponse
        }

        let callback = try await authenticate(startURL)
        let callbackComponents = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        let callbackState = callbackComponents?.queryItems?.first { $0.name == "state" }?.value
        let code = callbackComponents?.queryItems?.first { $0.name == "code" }?.value
        guard callback.scheme == SyncConfiguration.callbackScheme,
              callback.host == "auth",
              callback.path == "/callback",
              callbackState == state,
              let code,
              !code.isEmpty else {
            throw AuthClientError.invalidCallback
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/auth/exchange"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            MobileAuthExchangeRequest(code: code, state: state, codeVerifier: pkce.verifier)
        )
        let response = try await transport.send(request)
        guard (200..<300).contains(response.statusCode),
              let token = response.header("set-auth-token"),
              !token.isEmpty else {
            throw authError(response)
        }
        try sessionStore.save(token: token)
        do {
            return try await account()
        } catch {
            try? sessionStore.clear()
            throw error
        }
    }

    func account() async throws -> Account {
        let response = try await transport.send(try authorizedRequest(path: "v1/account"))
        guard response.statusCode == 200,
              let account = try? JSONDecoder().decode(Account.self, from: response.data) else {
            throw authError(response)
        }
        return account
    }

    func signOut() async throws {
        defer { try? sessionStore.clear() }
        var request = try authorizedRequest(path: "v1/auth/sign-out")
        request.httpMethod = "POST"
        let response = try await transport.send(request)
        guard response.statusCode == 204 else {
            throw authError(response)
        }
    }

    func deleteAccount() async throws {
        var request = try authorizedRequest(path: "v1/account")
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["confirmation": "DELETE"])
        let response = try await transport.send(request)
        guard response.statusCode == 204 else {
            throw authError(response)
        }
        try sessionStore.clear()
    }

    private func authorizedRequest(path: String) throws -> URLRequest {
        guard let token = try sessionStore.token(), !token.isEmpty else {
            throw AuthClientError.invalidResponse
        }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        return request
    }

    private func authError(_ response: HTTPResponse) -> AuthClientError {
        if let envelope = try? JSONDecoder().decode(GuideSyncErrorEnvelope.self, from: response.data) {
            return .server(status: response.statusCode, message: envelope.error.message)
        }
        return response.statusCode == 0 ? .invalidResponse : .server(
            status: response.statusCode,
            message: "Authentication failed (\(response.statusCode))."
        )
    }
}
