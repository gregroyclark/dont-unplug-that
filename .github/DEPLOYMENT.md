# Deployment setup

No store or Cloudflare credentials are committed to the repository. Pull
requests only run validation. Store delivery is available through manual
workflows. Cloudflare delivery runs on pushes to `main` or `master` and is also
available manually by full 40-character commit SHA. Every delivery stops before
a build when required configuration is absent.

The confirmed Apple listing is **Don't Unplug That**, App Store Connect app ID
`6799321398`, with bundle ID and SKU `com.matson.dont-unplug-this`. The Google
Play package is provisionally `com.dontunplugthat.app` until Greg confirms the
listing.

These platform identifiers must remain separate: Apple's identifier contains
hyphens, which are not valid in an Android application ID. `App/Skip.env` must
therefore set `PRODUCT_BUNDLE_IDENTIFIER = com.matson.dont-unplug-this` and an
explicit valid `ANDROID_APPLICATION_ID` matching the Play listing. The scaffold
already carries those separate identifiers.

## GitHub environments

Create protected GitHub environments. Restrict who may approve deployments
and prevent self-review if the repository plan supports it.

### `ios-testflight`

Repository or environment variables:

- `ASC_APP_ID`: `6799321398` (this is also the workflow default)
- `PRODUCT_BUNDLE_IDENTIFIER`: `com.matson.dont-unplug-this` (workflow default)
- `APPLE_TEAM_ID`: `MV7BS32ZA2`

Repository or environment secrets:

- `ASC_KEY_ID`: App Store Connect team API key ID
- `ASC_ISSUER_ID`: issuer ID for that API key
- `ASC_PRIVATE_KEY_BASE64`: base64 of the complete `AuthKey_*.p8` file

These exact three secrets and three variables are now configured in the GitHub
repository. The private key is decoded only on the ephemeral runner. Xcode uses
it with `-allowProvisioningUpdates` for automatic signing and provisioning, and
`altool` uses the same key to validate and upload the IPA.

Before the first run, Gareth must:

1. Confirm App Store Connect app `6799321398` and register the matching bundle
   ID. The app listing now exists, but the repository identifier must match it.
2. Accept any pending Apple agreements.
3. Keep the configured App Store Connect team API key authorized for Developer
   Resources and build uploads. No Apple ID password is used in CI.
4. Allow Xcode to manage the distribution signing assets with that key. The
   workflow does not require a checked-in or secret `.p12` or provisioning
   profile.
5. Configure TestFlight test information and the intended internal tester
   group in App Store Connect. The workflow uploads a build; it does not submit
   an App Store version for review or create tester groups.

Run **Deliver iOS to TestFlight** manually with an immutable commit SHA when a
specific PR build is intended. The default build number is
`GITHUB_RUN_NUMBER * 100 + GITHUB_RUN_ATTEMPT`; provide a higher explicit number
if App Store Connect already contains larger builds. The workflow uses GitHub's
`xcode-27` preview runner because multimodal Foundation Models image attachments
require the iOS 27 SDK.

Pull-request validation deliberately splits the mobile build across two jobs.
The existing Intel runner keeps Skip 1.9.5's Android Swift build on an Xcode
26-compatible toolchain, while a separate `xcode-27` job compiles the unsigned
iOS simulator app with Android disabled. This makes Foundation Models compile
failures visible without asking the incompatible Skip Android toolchain to run
under Xcode 27.

### `google-play-internal`

Environment variable:

- `ANDROID_PACKAGE_NAME`: the package Greg creates in Play Console; the
  provisional workflow default is `com.dontunplugthat.app`

Environment secrets:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: minified Google service-account JSON
  linked to Play Console
- `ANDROID_KEYSTORE_BASE64`: base64 of the stable Play upload keystore
- `ANDROID_KEYSTORE_PASSWORD`: upload keystore password
- `ANDROID_KEY_ALIAS`: upload-key alias
- `ANDROID_KEY_PASSWORD`: upload-key password

Before the first run, Greg must:

1. Complete the Play Console's government-ID, physical Android-device, and
   phone verification. The workflow is ready in code, but the personal Play
   Console account still blocks app creation until the owner completes those
   checks; the repository cannot bypass them.
2. Create the matching Google Play app and complete every Play Console setup
   item required before an internal release can be committed.
3. Enable the Google Play Android Developer API for the service account's Cloud
   project and grant that service account app-level permission to release to
   testing tracks.
4. Enable Play App Signing and retain the stable upload keystore represented by
   these secrets. Never generate a replacement key in CI.
5. Configure the internal testing tester list or Google Group.

Run **Deliver Android to Google Play Internal** manually with an immutable
commit SHA when a specific PR build is intended. It builds a signed `.aab` and
commits it only to the `internal` track. It never changes production.

### `cloudflare-production`

Cloudflare Containers are generally available on the Workers Paid plan. Protect
this environment before using **Deploy Vapor API to Cloudflare**.

Environment variable:

- `CLOUDFLARE_ACCOUNT_ID`: the account that owns the Worker and Container

Environment secret:

- `CLOUDFLARE_API_TOKEN`: narrowly scoped token able to deploy the Worker and
  its Container image and inspect Container rollout status in that account

The workflow runs automatically when a commit reaches `main` or `master`; it
can also be dispatched manually with a full 40-character commit SHA. It checks
both values and all required checkout files before it builds or deploys. It runs `npm ci`,
checks committed Wrangler-generated bindings, executes the proxy tests,
performs Wrangler's Docker-backed dry run, and only then deploys. It records the
exact source SHA, public URL reported by Wrangler, and Wrangler deployment data
without printing secrets. It performs an immediate single-instance rollout,
waits up to ten minutes for the named Container application to report a ready
or active image/version, then allows up to five minutes for the public cold
start before verifying `/health`, fixture `/v1/guides/analyze`, and blank-image
`400` behavior.

For local preparation, Docker's daemon must be active:

```sh
cd Cloudflare
npm ci
npm run types:generate
npm run check
npm run config:check
cd ..
docker build --platform linux/amd64 --tag dont-unplug-that-server:local .
```

The Worker uses one stable `fixture-api` instance and forwards the original
request to Vapor. It does not log request bodies or sensitive headers. Inspect
Worker logs and traces through Cloudflare Observability after a release. A
container can cold-start after its ten-minute idle sleep.

Rollback is a separate approved release operation. For the complete API,
manually redeploy a known-good commit SHA so Wrangler rebuilds and releases its
matching Worker and Container image. `cd Cloudflare && npx wrangler rollback <version-id> --name dont-unplug-that-api`
rolls back only the Worker and is safe only when the active Container image is
known to be compatible. The first release can only be replaced by redeploying a
known-good commit or disabling the Worker under separate authority.

## Acceptance gates

A green workflow proves build and upload operations, not complete device
acceptance. Record each layer independently:

1. **Code/CI:** Shared and server tests pass; Skip verifies and exports both
   platforms on its Xcode 26-compatible runner; the separate Xcode 27 iOS gate
   compiles the Foundation Models implementation.
2. **iOS upload:** Apple accepts the exact bundle, version, build, and commit.
3. **TestFlight:** App Store Connect finishes processing and the exact build is
   available to the intended internal tester group.
4. **Google Play upload:** the edit commits the exact package and version code
   to the internal track.
5. **Google Play testing:** Play finishes processing and the intended tester is
   eligible.
6. **Physical devices:** install, launch, photo capture/selection, on-device
   model availability, annotated explanation, uncertainty, unplug-impact, and
   safety-escalation states pass on at least one eligible iPhone and one
   supported Android device.

Store app creation, agreements, tester groups, processing, and physical-device
proof are deliberately outside a successful upload job.

## Credential handling

- Never store `.p8`, `.p12`, `.mobileprovision`, service-account JSON, or
  keystore files in Git.
- Rotate a credential immediately if it appears in a workflow log or artifact.
- Keep store environments protected and do not expose their secrets to pull
  request workflows.
- Prefer narrowly scoped service credentials. Apple ID passwords and personal
  session cookies are not CI credentials.

References: [Skip deployment](https://skip.dev/docs/deployment/),
[Apple build uploads](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/),
[App Store Connect API keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api),
[Google Play bundle upload](https://developers.google.com/android-publisher/api-ref/rest/v3/edits.bundles/upload),
and [GitHub Swift CI](https://docs.github.com/en/actions/tutorials/build-and-test-code/swift).
