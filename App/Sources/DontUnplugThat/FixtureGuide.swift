import DontUnplugThatShared

enum FixtureGuide {
    static func make() -> Guide {
        Guide(
            title: "Front-of-house streaming rack",
            summary: "This appears to be a small streaming system where power, audio, network, and computing depend on one another.",
            components: [
                GuideComponent(
                    displayNumber: 1,
                    name: "Power conditioner",
                    kind: .component,
                    location: NormalizedCoordinate(x: 0.16, y: 0.20),
                    likelyPurpose: "Distributes filtered power to several devices in the rack.",
                    unpluggingImpact: "Several or all devices in the rack may turn off together.",
                    evidenceLevel: .inferred,
                    uncertaintyNotes: "The rear outlets are not visible, so the exact downstream devices cannot be confirmed.",
                    safetyWarning: "Do not disconnect mains power from a live rack. Ask the system owner or a qualified technician."
                ),
                GuideComponent(
                    displayNumber: 2,
                    name: "Audio interface",
                    kind: .component,
                    location: NormalizedCoordinate(x: 0.33, y: 0.43),
                    likelyPurpose: "Converts microphone or mixer audio into a signal for the streaming computer.",
                    unpluggingImpact: "The stream may continue without sound, or the streaming app may lose its audio device.",
                    evidenceLevel: .observed,
                    uncertaintyNotes: "The USB destination is partly hidden, so the computer connection is inferred.",
                    safetyWarning: nil
                ),
                GuideComponent(
                    displayNumber: 3,
                    name: "Blue network uplink",
                    kind: .connection,
                    location: NormalizedCoordinate(x: 0.68, y: 0.27),
                    likelyPurpose: "Likely carries network access from the switch to the router or building network.",
                    unpluggingImpact: "The streaming computer and other rack devices may lose network access.",
                    evidenceLevel: .inferred,
                    uncertaintyNotes: "The far end is outside the photo, so its destination cannot be verified.",
                    safetyWarning: "Do not unplug it during a live stream; service may stop immediately."
                ),
                GuideComponent(
                    displayNumber: 4,
                    name: "Streaming computer",
                    kind: .component,
                    location: NormalizedCoordinate(x: 0.78, y: 0.57),
                    likelyPurpose: "Runs the software that combines audio and video and sends the stream.",
                    unpluggingImpact: "The active stream and any local recording may stop without a clean shutdown.",
                    evidenceLevel: .observed,
                    uncertaintyNotes: "The screen is not readable, so the currently running software cannot be confirmed.",
                    safetyWarning: "Do not remove power while it may be recording; files can be damaged."
                ),
                GuideComponent(
                    displayNumber: 5,
                    name: "Battery backup",
                    kind: .component,
                    location: NormalizedCoordinate(x: 0.54, y: 0.79),
                    likelyPurpose: "May keep part of the rack running briefly during a power interruption.",
                    unpluggingImpact: "Protected equipment may switch to battery or lose power, depending on the unseen outlet wiring.",
                    evidenceLevel: .unclear,
                    uncertaintyNotes: "The power cabling and battery status are not visible enough to identify what it protects.",
                    safetyWarning: "Do not disconnect or open battery equipment. Capture the rear labels or ask a qualified technician."
                )
            ]
        )
    }
}
