import Foundation
import Testing
@testable import DontUnplugThat

@Suite("Analysis response validation")
struct OnDeviceAnalyzerTests {
    func item(photoIndex: Int = 0, x: Double = 0.5, y: Double = 0.5) -> AnalysisItemPayload {
        AnalysisItemPayload(name: "Cable", kind: "connection", photoIndex: photoIndex,
            x: x, y: y, likelyPurpose: "Unknown connection", unpluggingImpact: "May interrupt service",
            evidenceLevel: "unclear", uncertaintyNotes: "Destination is hidden", safetyWarning: "")
    }

    @Test("Accepts a single grounded item without requiring invented components")
    func singleItem() throws {
        let guide = try OnDeviceAnalyzer.guide(from: AnalysisPayload(title: "Setup", summary: "One visible cable",
            items: [item()]), photoCount: 1)
        #expect(guide.components.count == 1)
        #expect(guide.components[0].safetyWarning != nil)
    }

    @Test("Rejects nonexistent photos and invalid coordinates instead of relocating pins")
    func invalidPins() {
        let invalid = [item(photoIndex: -1), item(photoIndex: 1), item(x: -0.1),
            item(y: 1.1), item(x: .nan), item(y: .infinity)]
        for badItem in invalid {
            #expect(throws: OnDeviceAnalyzerError.self) {
                try OnDeviceAnalyzer.guide(from: AnalysisPayload(title: "Setup", summary: "",
                    items: [badItem]), photoCount: 1)
            }
        }
    }

    @Test("Rejects empty results, excessive items, and unsupported input counts")
    func invalidCounts() {
        for count in [0, 13] {
            #expect(throws: OnDeviceAnalyzerError.self) {
                try OnDeviceAnalyzer.guide(from: AnalysisPayload(title: "Setup", summary: "",
                    items: Array(repeating: item(), count: count)), photoCount: 1)
            }
        }
        for count in [0, 4] {
            #expect(throws: OnDeviceAnalyzerError.self) {
                try OnDeviceAnalyzer.guide(from: AnalysisPayload(title: "Setup", summary: "",
                    items: [item()]), photoCount: count)
            }
        }
    }

    @Test("Accepts valid fenced JSON and preserves the selected photo")
    func fencedJSON() throws {
        let payload = AnalysisPayload(title: "Setup", summary: "One cable", items: [item(photoIndex: 2)])
        let json = String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
        let guide = try OnDeviceAnalyzer.guide(fromJSON: "```json\n" + json + "\n```", photoCount: 3)
        #expect(guide.components[0].photoIndex == 2)
    }

    @Test("Malformed JSON becomes an actionable analysis error")
    func malformedJSON() {
        #expect(throws: OnDeviceAnalyzerError.self) {
            try OnDeviceAnalyzer.guide(fromJSON: "Not a guide", photoCount: 1)
        }
    }
}
