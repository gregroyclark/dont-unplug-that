import Foundation
import Testing
@testable import DontUnplugThatShared

@Test("Shared guide request and response survive a JSON round trip")
func guideAnalysisJSONRoundTrip() throws {
    let component = GuideComponent(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        displayNumber: 1,
        name: "Power conditioner",
        location: NormalizedCoordinate(x: 0.25, y: 0.75),
        startupInstructions: "Turn on first.",
        shutdownInstructions: "Turn off last.",
        neverTouchInstructions: "Leave the voltage selector alone."
    )
    let response = AnalyzeGuideResponse(
        guide: Guide(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Sunday setup",
            components: [component]
        ),
        analysisMode: .fixture,
        warnings: ["Fixture response"]
    )

    let data = try JSONEncoder().encode(response)
    let decoded = try JSONDecoder().decode(AnalyzeGuideResponse.self, from: data)

    #expect(decoded == response)
}

@Test("Coordinates report whether they are normalized")
func coordinateNormalization() {
    #expect(NormalizedCoordinate(x: 0, y: 1).isNormalized)
    #expect(NormalizedCoordinate(x: 0.42, y: 0.58).isNormalized)
    #expect(!NormalizedCoordinate(x: -0.01, y: 0.5).isNormalized)
    #expect(!NormalizedCoordinate(x: 0.5, y: 1.01).isNormalized)
}

@Test("Analyze request carries image metadata")
func analyzeRequestMetadata() {
    let request = AnalyzeGuideRequest(
        base64EncodedImage: "aW1hZ2U=",
        mediaType: .jpeg,
        suggestedTitle: "Rack"
    )

    #expect(request.mediaType == .jpeg)
    #expect(request.suggestedTitle == "Rack")
}
