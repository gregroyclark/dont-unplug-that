# Daylight native app verification — September 7, 2026

## Android test APK

Android debug build succeeded with Gradle `:app:assembleDebug`. Package `com.dontunplugthat.app`, version 0.0.1 (1). The Swift app library targets ARM64; minimum Android API 28 (Android 9). This is a debug-signed test build, not a Google Play release.

Verified APK signature, installation and cold launch on an Android API 36 ARM64 emulator. At 320 × 640 the welcome screen fits without horizontal clipping; Phosphor icons render correctly. Saved Guides opens with its empty state and closes using Done. The system photo picker opens and cancels successfully. No app crash was recorded during these checks.

Screenshots: `qa/android-daylight-welcome.png`, `qa/android-daylight-library.png`.

Build fixes include Apple-only import guards, FoundationNetworking imports for Android, bridged SHA-256/photo processing, supported SwiftUI controls, bounded screen width, and bundled Phosphor icons. The on-device model, photo analysis, authentication, sync and photo derivative behavior have not been end-to-end verified on a physical device. The host-side PKCE RFC vector was checked separately.

APK SHA-256: `8620de19d7c06cf59e41758f4962a71acd88f946e09f5f1f69eea4a10f44edb1`.

## iOS status

The Daylight SwiftUI source is implemented, but an iOS app build and simulator visual verification remain pending. The Android verification above does not establish iOS readiness.
