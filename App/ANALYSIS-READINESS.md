# Photo analysis: platform requirements and acceptance plan

Updated September 13, 2026. Neither platform is certified end to end by this
review. An installable app is not evidence of working photo analysis.

## Current integration

| Surface | Implementation and native bridge | Remaining proof |
| --- | --- | --- |
| iPhone inference | Native Swift `FoundationModels`: `SystemLanguageModel`, image `Attachment`s, `LanguageModelSession`, and `@Generable` output. Requires the iOS 27 SDK/Swift 6.4 build branch, iOS 27+, eligible Apple Intelligence hardware, enabled intelligence, and available vision/guided-generation capabilities. No API key. | Compile with the required SDK, then test real photos on a compatible physical iPhone. The installed local Swift toolchain is 6.3.3, which excludes this branch. |
| Android inference | Skip Fuse native Swift → generated JNI/Skip bridge → Kotlin ML Kit `Generation` → AICore/Gemini Nano. `genai-prompt:1.0.0-beta4` is already declared in `Skip/skip.yml`. The bridge exposes status, download, and inference; status errors now propagate to Swift. No cloud AI key. | Regenerate and compile the changed bridge; verify model status/download/inference on a supported physical phone. Android 9 installation support does not imply Prompt API eligibility. |
| Camera/library | SkipKit `withMediaPicker` returns native photo URLs; Android resolves URIs with `ContentResolver`. | Camera permissions, cancellation, one/two/three photos, and URI lifetime on both platforms. |
| Image geometry | Android inference uses `ImageDecoder` (API 28+) for orientation-aware, bounded software bitmaps. Canvas metadata uses bounds and EXIF rather than decoding a full camera image. Apple inference passes file URLs to Foundation Models, which handles image preprocessing. | Rotated/mirrored images, HEIC/JPEG, portrait/landscape, pin alignment before and after save. |
| Guide storage | Shared Swift guide model and existing local repository. Better Auth/D1/private R2 are optional sync integrations. | Save/reopen after process restart; separately test accounts and cross-device sync. |

The Vapor endpoint remains a deterministic development fixture. It is not a
production inference integration or fallback. The local/shared and Worker validators now accept 1–12 items consistently. The
Worker change must be deployed before releasing this app change for optional sync
of guides with fewer than five items. Older app clients may reject such guides;
coordinate client updates. No database migration is needed. No deployment was run.

No new server inference, API key,
model download service, or public photo upload was added.

## Changes in this patch

- Model readiness is visible before capture; capture requires an available model.
  Saved guides remain accessible even without model support.
- Retry and foreground refresh recover availability; downloads already in progress
  are rechecked every five seconds while the view is active.
- Android service-check exceptions retain diagnostic text rather than becoming a
  claim that the device is unsupported. `UNAVAILABLE` still cannot distinguish
  unsupported hardware from incomplete AICore configuration by itself.
- Old Apple OS versions, missing build integration, unavailable vision capabilities,
  and service-check failures have separate states.
- Inference rechecks readiness and uses a snapshot of its source photos.
- Model output accepts 1–12 grounded items, rejects an empty result, and no longer
  demands at least five items. Invalid coordinates and photo references are
  rejected instead of silently moving pins. Malformed JSON gets a retryable error.
- Android inference decodes at most 1600 pixels on the longest side, applies EXIF
  orientation, releases completed inference bitmaps, and checks for empty candidates.

Android currently requests JSON through its prompt and validates it afterward.
ML Kit offers structured output; adopting that requires its schema/KSP integration
and testing the generated Kotlin path. It is a reliability improvement to evaluate,
not a solution for unsupported hardware. Neither structured output nor valid
coordinates prove that an identification or unplugging explanation is correct.

## Acceptance gates, in order

1. Record the actual phone model, OS, app version/build, model availability result,
   and service error (if any). Do not log photo bodies or inference transcripts.
2. Build Android and iOS with their supported toolchains after explicit native-build
   authorization. Check Android ARM64 library packaging and the generated throwing
   status bridge; ensure iOS compiles the real Foundation Models branch.
3. On supported physical devices, test fresh model setup, download completion,
   unavailable model, retry, leaving/returning to the app, and offline inference
   after model download. On unsupported devices, explain the limitation before
   asking for photos.
4. Complete capture → analyze → inspect pins → save → restart → reopen for one,
   two, and three photos. Include EXIF rotation/mirroring and unreadable images.
5. Evaluate representative setups against human-reviewed expected observations.
   Check identification, pin placement, uncertainty, hidden cable destinations,
   and dangerous or unsupported claims. Record model version and latency.
6. Verify optional auth/sync separately; do not make successful login a prerequisite
   for local photo analysis.

Broad Android/iPhone coverage is a separate architecture decision. The current
plan remains private on-device inference. Supporting phones excluded by these
system APIs requires evaluating another local vision runtime/model (including
size, licensing, performance, and device support), or an explicitly approved
change to the no-cloud-AI product constraint. Neither is a drop-in bridge fix.

## Verification for this patch

The five production response-contract tests can run without building a mobile app:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  python3 App/scripts/test-analysis-contract.py
```

They cover small valid guides, malformed/fenced JSON, input/output count limits,
nonexistent photo references, nonfinite values, and out-of-bounds pins. Host tests
do not execute Foundation Models, ML Kit, JNI, camera UI, or SwiftUI.

Recorded checks for this patch: five analysis-contract tests, eight shared-model
tests, and six Worker contract tests passed; Worker TypeScript checking and Swift
syntax parsing passed. Worker contract tests ran in a Node-only Vitest configuration
without D1/R2. Skip 1.9.5 generated the updated Kotlin sources and throwing Swift/JNI
status bridge successfully using cached dependency metadata. Skip still warns that
it cannot infer actors for the external ML Kit async calls. No Kotlin/native app
compilation or physical-device inference was performed; source generation is not
runtime verification.

## API references

- [Apple multimodal prompting](https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting)
- [Apple iOS 27 capabilities](https://developer.apple.com/ios/whats-new/)
- [Google Prompt API setup and AICore troubleshooting](https://developers.google.com/ml-kit/genai/prompt/android/get-started)
- [Google Prompt API device support](https://developers.google.com/ml-kit/genai#device_support)
- [Android ImageDecoder](https://developer.android.com/reference/android/graphics/ImageDecoder)
