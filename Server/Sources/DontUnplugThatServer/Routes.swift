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
        guard !analysisRequest.photos.isEmpty else {
            throw Abort(.badRequest, reason: "At least one photo is required")
        }
        guard analysisRequest.photos.allSatisfy({ photo in
            !photo.base64EncodedImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            throw Abort(.badRequest, reason: "Photo data must not be empty")
        }

        return FixtureGuideAnalyzer.analyze(analysisRequest)
    }
}

/// Deterministic development data only. Production inference runs on-device.
enum FixtureGuideAnalyzer {
    static func analyze(_ request: AnalyzeGuideRequest) -> AnalyzeGuideResponse {
        let alternatePhotoIndex = request.photos.count > 1 ? 1 : 0

        let components = [
            GuideComponent(
                displayNumber: 1,
                name: "Power conditioner",
                location: NormalizedCoordinate(x: 0.16, y: 0.18),
                likelyPurpose: "Distributes protected mains power to the rack equipment.",
                unpluggingImpact: "Likely shuts down every device powered through it, including audio output.",
                evidenceLevel: .observed,
                uncertaintyNotes: "The front panel identifies the unit, but its rear wiring is outside the photo.",
                safetyWarning: "Mains electricity: do not open, rewire, or touch damaged or exposed connections. Stop and ask a qualified technician."
            ),
            GuideComponent(
                displayNumber: 2,
                name: "Audio mixer",
                location: NormalizedCoordinate(x: 0.50, y: 0.31),
                likelyPurpose: "Combines microphone and media signals and controls the main audio level.",
                unpluggingImpact: "Removes the mixed audio feed; connected amplifiers or speakers may make a loud pop.",
                evidenceLevel: .observed,
                uncertaintyNotes: "The faders and channel controls are visible, but connected sources are not."
            ),
            GuideComponent(
                displayNumber: 3,
                name: "Network switch",
                location: NormalizedCoordinate(x: 0.81, y: 0.22),
                likelyPurpose: "Connects control, media, or streaming devices on the local network.",
                unpluggingImpact: "Devices downstream may lose control, internet access, or media connectivity.",
                evidenceLevel: .inferred,
                uncertaintyNotes: "The port layout suggests a network switch; cable destinations are outside the photo."
            ),
            GuideComponent(
                displayNumber: 4,
                name: "Power amplifier",
                location: NormalizedCoordinate(x: 0.52, y: 0.84),
                likelyPurpose: "Raises the mixer signal to a level that can drive speakers.",
                unpluggingImpact: "The connected speakers will go silent and may pop if disconnected while active.",
                evidenceLevel: .inferred,
                uncertaintyNotes: "Its rack position and controls suggest an amplifier; speaker wiring is not fully visible.",
                safetyWarning: "The unit or connected wiring may be hot or carry hazardous voltage. Stop if anything is hot, damaged, wet, or arcing."
            ),
            GuideComponent(
                displayNumber: 5,
                name: "Blue Ethernet cable",
                kind: .connection,
                photoIndex: alternatePhotoIndex,
                location: NormalizedCoordinate(x: 0.67, y: 0.63),
                likelyPurpose: "Likely carries network data from the switch to another device.",
                unpluggingImpact: "The device at the unseen far end may lose network control or connectivity.",
                evidenceLevel: .unclear,
                uncertaintyNotes: "The far end is outside the photo, so its destination and exact role are unknown.",
                safetyWarning: "Don't unplug yet. Add a photo that shows the far end or ask the technician responsible for this setup."
            ),
            GuideComponent(
                displayNumber: 6,
                name: "Black IEC power lead",
                kind: .connection,
                photoIndex: alternatePhotoIndex,
                location: NormalizedCoordinate(x: 0.31, y: 0.58),
                likelyPurpose: "Likely supplies mains power from the conditioner to the amplifier.",
                unpluggingImpact: "The amplifier and its downstream speakers will immediately lose power.",
                evidenceLevel: .inferred,
                uncertaintyNotes: "The cable route is partly obscured, so its endpoints are inferred from position.",
                safetyWarning: "Do not disconnect a plug or socket that is hot, wet, damaged, buzzing, or arcing. Stop and ask a qualified technician."
            )
        ]

        return AnalyzeGuideResponse(
            guide: Guide(
                title: "Unfamiliar live-audio rack",
                summary: "This appears to be a small live-audio rack that routes source audio through a mixer and amplifier while sharing power and network connectivity.",
                components: components
            ),
            analysisMode: .fixture,
            warnings: [
                "Development fixture only. Production photo inference runs on-device; this server does not proxy an AI provider.",
                "Stop and ask a qualified professional before touching anything involving mains electricity, exposed wiring, plumbing, heat, pressure, leaks, or hissing."
            ]
        )
    }
}
