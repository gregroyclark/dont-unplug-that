import Foundation
import Testing
@testable import DontUnplugThatShared

@Test("Shared guide request and response survive a JSON round trip")
func guideAnalysisJSONRoundTrip() throws {
    let component = GuideComponent(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        displayNumber: 1,
        name: "Power conditioner",
        kind: .component,
        photoIndex: 1,
        location: NormalizedCoordinate(x: 0.25, y: 0.75),
        likelyPurpose: "Distributes power.",
        unpluggingImpact: "The rack loses power.",
        evidenceLevel: .inferred,
        uncertaintyNotes: "The rear wiring is not visible.",
        safetyWarning: "Stop around exposed mains wiring."
    )
    let response = AnalyzeGuideResponse(
        guide: Guide(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Sunday setup",
            summary: "A compact live-audio rack.",
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

@Test("Analyze request carries one or more photos")
func analyzeRequestPhotos() {
    let request = AnalyzeGuideRequest(
        photos: [
            GuidePhoto(base64EncodedImage: "aW1hZ2UtMQ==", mediaType: .jpeg),
            GuidePhoto(base64EncodedImage: "aW1hZ2UtMg==", mediaType: .png)
        ]
    )

    #expect(request.photos.count == 2)
    #expect(request.photos.map(\.mediaType) == [.jpeg, .png])
}
