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
