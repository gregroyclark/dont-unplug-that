# Don't Unplug That

Understand an unfamiliar physical setup before disconnecting anything.

The first product slice analyzes one to three photos, places numbered pins over
the equipment and connections it can identify, and explains:

- what each item likely is and does
- whether that conclusion is observed, inferred, or unclear
- what may stop or change if it is unplugged
- when the user should stop and ask a qualified technician

It is designed for unfamiliar networking, IT, AV, appliances, plumbing, and
electrical environments. It never declares that something is safe to unplug.
Authentication, hosted sharing, QR codes, history, and cloud AI are deferred.

## Swift end to end

All human-authored product code is Swift:

- `App/` is a Skip Fuse app. Its SwiftUI code runs on iOS and is compiled for Android by Skip.
- `Shared/` contains the `Codable` guide contract shared by the app and server.
- `Server/` is a Vapor API with a deterministic development fixture; production
  photo inference does not pass through it.

Skip's generated Android glue and the platform, package, and CI configuration files remain in their native formats. No product behavior or business logic is authored in Kotlin or JavaScript.

## Repository map

```text
App/       Skip Fuse mobile app for iOS and Android
Server/    Swift/Vapor API
Shared/    Shared Swift models and validation
.github/   Pull-request validation and manual store-delivery workflows
```

## MVP flow

1. Pick or take a photo of the setup.
2. Analyze the photos on device: Apple Foundation Models on iOS and ML Kit GenAI
   backed by AICore and Gemini Nano on Android.
3. Receive 5–12 components or connections with normalized `x` and `y`
   coordinates tied to the source photo.
4. Tap a numbered pin to understand the item, the visual evidence, and the
   likely downstream impact of unplugging it.
5. Add a close-up or stop and ask a qualified technician when the evidence or
   physical risk is unclear.

The server fixture keeps the contract testable without becoming a cloud fallback
for private photos.

## Local development

Requirements:

- macOS with Xcode 27 or newer for multimodal Apple Foundation Models
- Swift 6.4 or newer for the iOS 27 model integration
- Skip 1.9 or newer with its native Android toolchain
- Android Studio or the Android SDK for Android builds

Each package includes its own build instructions. No store credentials or AI keys belong in the repository.

## Delivery

Pull requests validate the shared models, server, and mobile app. Manual GitHub
Actions workflows package and submit builds to TestFlight and the Google Play
internal track after the corresponding store apps and repository secrets are
configured.

Store submission, processing, tester-group assignment, and successful installation on physical devices are separate acceptance gates. A green workflow alone does not prove on-device delivery.
