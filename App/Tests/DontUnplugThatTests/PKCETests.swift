import Testing
@testable import DontUnplugThat

@Test("PKCE matches the RFC 7636 S256 example")
func pkceRFCVector() {
    let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    #expect(PortableDigest.sha256URLSafe(verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
}

@Test("PKCE creates fresh URL-safe verifier and state values")
func pkceRandomValues() {
    let first = PKCEPair.make()
    let second = PKCEPair.make()
    let state = PKCEPair.randomState()

    #expect(first.verifier.count == 64)
    #expect(state.count == 64)
    #expect(first != second)
    #expect(first.verifier.allSatisfy { $0.isHexDigit })
    #expect(!first.challenge.contains("="))
}
