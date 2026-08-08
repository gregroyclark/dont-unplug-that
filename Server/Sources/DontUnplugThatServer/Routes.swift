import DontUnplugThatShared
import Foundation
import Vapor

struct HealthResponse: Content, Equatable {
    let status: String
}

extension AnalyzeGuideRequest: @retroactive Content {}
extension AnalyzeGuideResponse: @retroactive Content {}

func configure(_ application: Application) throws {
    application.get("health") { _ in
        HealthResponse(status: "ok")
    }

    application.post("v1", "guides", "analyze") { request throws -> AnalyzeGuideResponse in
        let analysisRequest = try request.content.decode(AnalyzeGuideRequest.self)
        guard !analysisRequest.base64EncodedImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "base64EncodedImage must not be empty")
        }

        return FixtureGuideAnalyzer.analyze(analysisRequest)
    }
}

enum FixtureGuideAnalyzer {
    static func analyze(_ request: AnalyzeGuideRequest) -> AnalyzeGuideResponse {
        let title = request.suggestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let guideTitle = title.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled setup"

        let components = [
            GuideComponent(
                displayNumber: 1,
                name: "Power conditioner",
                location: NormalizedCoordinate(x: 0.16, y: 0.18),
                startupInstructions: "Turn this on first.",
                shutdownInstructions: "Turn this off last.",
                neverTouchInstructions: "Do not change the voltage selector."
            ),
            GuideComponent(
                displayNumber: 2,
                name: "Audio mixer",
                location: NormalizedCoordinate(x: 0.50, y: 0.31),
                startupInstructions: "Confirm all channel faders are down, then power on.",
                shutdownInstructions: "Lower the master fader before powering off.",
                neverTouchInstructions: "Do not change the main output routing."
            ),
            GuideComponent(
                displayNumber: 3,
                name: "Wireless receiver",
                location: NormalizedCoordinate(x: 0.81, y: 0.22),
                startupInstructions: "Power on and confirm the expected channel.",
                shutdownInstructions: "Power off after the mixer.",
                neverTouchInstructions: "Do not rescan frequencies during an event."
            ),
            GuideComponent(
                displayNumber: 4,
                name: "Media player",
                location: NormalizedCoordinate(x: 0.31, y: 0.58),
                startupInstructions: "Wake the player and open the show playlist.",
                shutdownInstructions: "Stop playback before sleeping the player.",
                neverTouchInstructions: "Do not delete or reorder the master playlist."
            ),
            GuideComponent(
                displayNumber: 5,
                name: "Network switch",
                location: NormalizedCoordinate(x: 0.67, y: 0.63),
                startupInstructions: "Confirm the power and uplink lights are on.",
                shutdownInstructions: "Leave powered on unless maintenance requires otherwise.",
                neverTouchInstructions: "Do not unplug the uplink cable."
            ),
            GuideComponent(
                displayNumber: 6,
                name: "Amplifier",
                location: NormalizedCoordinate(x: 0.52, y: 0.84),
                startupInstructions: "Turn on only after the mixer is ready.",
                shutdownInstructions: "Turn off before the mixer and power conditioner.",
                neverTouchInstructions: "Do not change the limiter controls."
            )
        ]

        return AnalyzeGuideResponse(
            guide: Guide(title: guideTitle, components: components),
            analysisMode: .fixture,
            warnings: ["Fixture analysis only; no AI provider has been called."]
        )
    }
}
