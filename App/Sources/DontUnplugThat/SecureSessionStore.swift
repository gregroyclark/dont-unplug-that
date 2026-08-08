import Foundation
import SkipKeychain

protocol SessionStoring: Sendable {
    func token() throws -> String?
    func save(token: String) throws
    func clear() throws
}

struct SecureSessionStore: SessionStoring {
    private let key = "com.matson.dont-unplug-this.sync-session"

    func token() throws -> String? {
        try Keychain.shared.string(forKey: key)
    }

    func save(token: String) throws {
        guard !token.isEmpty else {
            throw AuthClientError.invalidResponse
        }
        try Keychain.shared.set(token, forKey: key, access: .unlockedThisDeviceOnly)
    }

    func clear() throws {
        try Keychain.shared.removeValue(forKey: key)
    }
}
