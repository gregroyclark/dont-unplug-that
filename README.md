# Don't Unplug That

Turn a photo of a complicated setup into a clear, editable operating guide.

The first product slice identifies the important parts of a setup, places numbered pins over the source photo, and lets the owner document three things for every component:

- startup instructions
- shutdown instructions
- warnings for anything that should never be touched

The guide is designed for phone-first use and will export to image and PDF. Authentication, hosted sharing, and QR codes are intentionally deferred.

## Swift end to end

All human-authored product code is Swift:

- `App/` is a Skip Fuse app. Its SwiftUI code runs on iOS and is compiled for Android by Skip.
- `Shared/` contains the `Codable` guide contract shared by the app and server.
- `Server/` is a Vapor API that keeps AI provider credentials off the device.

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
2. Send the image to the Swift server for component analysis.
3. Receive 5–12 components with normalized `x` and `y` coordinates.
4. Review numbered pins and edit the three instruction categories.
5. Export the finished guide as an image or PDF.

The initial scaffold uses fixture analysis so the interface and API contract can evolve independently of the eventual AI provider.

## Local development

Requirements:

- macOS with Xcode 26 or newer
- Swift 6.2 or newer
- Skip 1.9 or newer with its native Android toolchain
- Android Studio or the Android SDK for Android builds

Each package includes its own build instructions. No store credentials or AI keys belong in the repository.

## Delivery

Pull requests validate the shared models, server, and mobile app. Manual GitHub Actions workflows will package and submit builds to TestFlight and the Google Play internal track after the corresponding store apps and repository secrets are configured.

Store submission, processing, tester-group assignment, and successful installation on physical devices are separate acceptance gates. A green workflow alone does not prove on-device delivery.
