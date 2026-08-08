import Foundation

#if !SKIP
import CryptoKit
#endif

struct PKCEPair: Equatable, Sendable {
    let verifier: String
    let challenge: String

    static func make() -> PKCEPair {
        let verifier = randomValue()
        return PKCEPair(verifier: verifier, challenge: PortableDigest.sha256URLSafe(verifier))
    }

    static func randomState() -> String {
        randomValue()
    }

    private static func randomValue() -> String {
        (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "")
    }
}

enum PortableDigest {
    static func sha256(_ data: Data) -> Data {
        #if SKIP
        return data.sha256()
        #else
        return Data(CryptoKit.SHA256.hash(data: data))
        #endif
    }

    static func sha256Base64(_ data: Data) -> String {
        sha256(data).base64EncodedString()
    }

    static func sha256URLSafe(_ value: String) -> String {
        guard let data = value.data(using: .utf8) else {
            return ""
        }
        return base64URL(sha256(data))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
