import DontUnplugThatShared
import Testing
@testable import DontUnplugThat

@Suite("Fixture guide")
struct FixtureGuideTests {
    @Test("Includes five fully annotated components")
    func testSkipModule() {
        let guide = FixtureGuide.make()

        #expect(guide.components.count == 5)
        #expect(guide.components.map(\.displayNumber) == [1, 2, 3, 4, 5])
        #expect(guide.components.allSatisfy { !$0.name.isEmpty })
        #expect(guide.components.allSatisfy { !$0.startupInstructions.isEmpty })
        #expect(guide.components.allSatisfy { !$0.shutdownInstructions.isEmpty })
        #expect(guide.components.allSatisfy { !$0.neverTouchInstructions.isEmpty })
    }

    @Test("Keeps every pin inside normalized bounds")
    func keepsPinsInsideNormalizedBounds() {
        let guide = FixtureGuide.make()

        #expect(guide.components.allSatisfy { component in
            component.location.isNormalized
        })
    }
}
