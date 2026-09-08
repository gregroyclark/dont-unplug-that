# Android test APK

From `App/`, with Skip, its Swift Android SDK, Gradle, Java and the Android SDK installed:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
ANDROID_HOME="$HOME/Library/Android/sdk" \
gradle -p Android :app:assembleDebug --no-daemon --console=plain --max-workers=2
```

The APK is written to `.build/Android/app/outputs/apk/debug/app-debug.apk`. This builds locally and signs with the local debug key; it does not upload to Google Play or GitHub. The tested build contains an ARM64 Swift app library and requires Android 9 or newer. On-device AI additionally requires supported hardware/model availability.

Copy the APK to your Android device, open it, and allow installation from that source when Android prompts. Keep using the same debug key for test upgrades. A store-signed installation cannot be replaced by this debug-signed APK.

See `../Design/native-qa.md` for the latest checks and limitations. Android icons are bundled from Phosphor under the license in `Sources/DontUnplugThat/Resources/Phosphor-LICENSE.txt`.

## Hosted Daylight test build — September 7, 2026

[Download the signed test APK](https://pub-3c0f7758d6b34898bdde0c139916434e.r2.dev/Dont-Unplug-That-Daylight-2026-09-07.apk).

The file is hosted in the dedicated `dont-unplug-that-downloads` R2 bucket. Its public test URL serves the APK as an attachment. Do not place user photos, credentials, or private data in this bucket. The separate `dont-unplug-that-guide-photos` bucket remains private.

SHA-256: `c6fbe6c39307886232e5929a2f3d1e3f7cc25b4bfc42447738af7c97f4898db7`.

If the phone browser stalls while finalizing the APK download, use the [ZIP download](https://pub-3c0f7758d6b34898bdde0c139916434e.r2.dev/Dont-Unplug-That-Daylight-2026-09-07.zip) (75.14 MB). Extract it and open `Dont-Unplug-That-Daylight.apk`. The archive contains the identical signed APK; no app changes or rebuild are involved.

ZIP SHA-256: `bc7a4ee13f16f2c37d19387eab07b6b5e4dd4782cb24e8dda9aafa4130b0e8e8`.
