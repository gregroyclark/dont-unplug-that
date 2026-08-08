import DontUnplugThatShared
import Testing
@testable import DontUnplugThat

@Suite("Fixture guide")
struct FixtureGuideTests {
    @Test("Includes five grounded setup findings")
    func includesFiveGroundedFindings() {
        let guide = FixtureGuide.make()

        #expect(guide.components.count == 5)
        #expect(guide.components.map(\.displayNumber) == [1, 2, 3, 4, 5])
        #expect(!guide.summary.isEmpty)
        #expect(guide.components.allSatisfy { !$0.name.isEmpty })
        #expect(guide.components.allSatisfy { !$0.likelyPurpose.isEmpty })
        #expect(guide.components.allSatisfy { !$0.unpluggingImpact.isEmpty })
        #expect(guide.components.allSatisfy { !$0.uncertaintyNotes.isEmpty })
        #expect(guide.components.contains { $0.kind == .connection })
        #expect(guide.components.filter { $0.evidenceLevel == .unclear }.allSatisfy { $0.safetyWarning != nil })
    }

    @Test("Keeps every pin inside normalized bounds")
    func keepsPinsInsideNormalizedBounds() {
        let guide = FixtureGuide.make()

        #expect(guide.components.allSatisfy { component in
            component.location.isNormalized
        })
    }

    @Test("Normalizes model output at the app boundary")
    func normalizesModelOutput() throws {
        let item = AnalysisItemPayload(
            name: "  ",
            kind: "unknown",
            photoIndex: 9,
            x: -2.0,
            y: 3.0,
            likelyPurpose: "",
            unpluggingImpact: "",
            evidenceLevel: "guess",
            uncertaintyNotes: "",
            safetyWarning: "  "
        )
        let payload = AnalysisPayload(
            title: "",
            summary: "",
            items: Array(repeating: item, count: 5)
        )

        let guide = try OnDeviceAnalyzer.guide(from: payload, photoCount: 2)

        #expect(guide.components.count == 5)
        #expect(guide.components.allSatisfy { $0.photoIndex == 1 })
        #expect(guide.components.allSatisfy { $0.location == NormalizedCoordinate(x: 0.0, y: 1.0) })
        #expect(guide.components.allSatisfy { $0.evidenceLevel == .unclear })
        #expect(guide.components.allSatisfy { !$0.uncertaintyNotes.isEmpty })
        #expect(guide.components.allSatisfy { $0.safetyWarning != nil })
    }

    @Test("Uses a stable canvas ratio before a photo is available")
    func usesFallbackPhotoAspectRatio() async {
        let ratio = await SelectedPhotoMetadata.aspectRatio(for: nil)

        #expect(ratio == 4.0 / 3.0)
    }
}
