import DontUnplugThatShared

enum FixtureGuide {
    static func make() -> Guide {
        Guide(
            title: "Front-of-house streaming rack",
            components: [
                GuideComponent(
                    displayNumber: 1,
                    name: "Power conditioner",
                    location: NormalizedCoordinate(x: 0.16, y: 0.20),
                    startupInstructions: "Switch this on first, then wait ten seconds before powering anything else.",
                    shutdownInstructions: "Switch this off last, after every component below is dark.",
                    neverTouchInstructions: "Do not unplug the yellow power lead on the rear panel."
                ),
                GuideComponent(
                    displayNumber: 2,
                    name: "Audio interface",
                    location: NormalizedCoordinate(x: 0.33, y: 0.43),
                    startupInstructions: "Press the round power button once and confirm the USB light turns green.",
                    shutdownInstructions: "Mute the monitor output, then hold the power button for two seconds.",
                    neverTouchInstructions: "Leave the gain knobs at their taped positions."
                ),
                GuideComponent(
                    displayNumber: 3,
                    name: "Network switch",
                    location: NormalizedCoordinate(x: 0.68, y: 0.27),
                    startupInstructions: "It starts with the power conditioner. Confirm the first four link lights blink.",
                    shutdownInstructions: "No separate shutdown is needed.",
                    neverTouchInstructions: "Never unplug the blue cable in port 1; it feeds the stream encoder."
                ),
                GuideComponent(
                    displayNumber: 4,
                    name: "Streaming computer",
                    location: NormalizedCoordinate(x: 0.78, y: 0.57),
                    startupInstructions: "Press the rear power button, sign in, and open the streaming preset.",
                    shutdownInstructions: "Quit the streaming app and use Shut Down from the system menu.",
                    neverTouchInstructions: "Do not disconnect either USB capture cable while the app is open."
                ),
                GuideComponent(
                    displayNumber: 5,
                    name: "Battery backup",
                    location: NormalizedCoordinate(x: 0.54, y: 0.79),
                    startupInstructions: "Hold the power button until one beep, then confirm the battery icon is solid.",
                    shutdownInstructions: "Hold for three seconds only after the power conditioner is off.",
                    neverTouchInstructions: "Do not press the recessed test button during a service."
                )
            ]
        )
    }
}
