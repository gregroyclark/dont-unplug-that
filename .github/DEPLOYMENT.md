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

Cloudflare Containers require the Workers Paid plan. Protect this environment
before using **Deploy API to Cloudflare**.

Environment variable:

- `CLOUDFLARE_ACCOUNT_ID`: the account that owns the Worker and Container

Environment secret:

- `CLOUDFLARE_API_TOKEN`: narrowly scoped token able to deploy the Worker and
  its Container image, migrate D1, read Worker secret names, and inspect
  Container rollout status in that account

The Worker also requires five Cloudflare Worker secrets. Configure them with
Wrangler, not as repository files:

- `BETTER_AUTH_SECRET`: at least 32 cryptographically random bytes
- `APPLE_CLIENT_ID`: the Apple Services ID used by the web OAuth flow
- `APPLE_CLIENT_SECRET`: a current Apple client-secret JWT
- `GOOGLE_CLIENT_ID`: a Google OAuth web client ID
- `GOOGLE_CLIENT_SECRET`: that client's secret

Bootstrap the resources once from `Cloudflare/` while logged into the intended
account:

```sh
npx wrangler d1 create dont-unplug-that
npx wrangler r2 bucket create dont-unplug-that-guide-photos
npx wrangler secret put BETTER_AUTH_SECRET
npx wrangler secret put APPLE_CLIENT_ID
npx wrangler secret put APPLE_CLIENT_SECRET
npx wrangler secret put GOOGLE_CLIENT_ID
npx wrangler secret put GOOGLE_CLIENT_SECRET
npx wrangler d1 migrations apply DB --remote
```

Copy the D1 database ID returned by the first command into the `database_id`
field for the `DB` binding in `Cloudflare/wrangler.jsonc`. Keep the R2 bucket
private; do not enable an `r2.dev` domain or public custom domain. For local
OAuth testing only, copy `.dev.vars.example` to ignored `.dev.vars` and fill in
local values.

The canonical production Worker host is
`https://dont-unplug-that-api.gregroyclark.workers.dev`; it is compiled into
the shared mobile `SyncConfiguration` for both platforms. If the Worker name or
account subdomain changes, update that constant before shipping either app.

Register these provider callback URLs:

```text
https://dont-unplug-that-api.gregroyclark.workers.dev/api/auth/callback/apple
https://dont-unplug-that-api.gregroyclark.workers.dev/api/auth/callback/google
```

Apple needs the Worker host attached to the Services ID and its return URL.
Google needs the exact callback as an authorized redirect URI. Sign-in remains
unavailable until those console settings and secrets agree.

The workflow runs automatically when a commit reaches `main` or `master`; it
can also be dispatched manually with a full 40-character commit SHA. It checks
both values and all required checkout files before it builds or deploys. It
runs `npm ci`, checks committed Wrangler-generated bindings, executes isolated
Worker, D1, and R2 tests, performs Wrangler's Docker-backed dry run, confirms
required Worker secret names, applies pending D1 migrations, and only then
deploys. It records the
exact source SHA, public URL reported by Wrangler, and Wrangler deployment data
without printing secrets. It performs an immediate single-instance rollout,
waits up to ten minutes for the named Container application to report a ready
or active image/version, then allows up to five minutes for the public cold
start before verifying `/health`, fixture `/v1/guides/analyze`, blank-image
`400` behavior, and an unauthenticated sync `401`.

For local preparation, Docker's daemon must be active:

```sh
cd Cloudflare
npm ci
npm run types:generate
npm run check
npx wrangler d1 migrations apply DB --local
npm run config:check
cd ..
docker build --platform linux/amd64 --tag dont-unplug-that-server:local .
```

The Worker handles Better Auth and private guide sync directly. It forwards only
the exact fixture routes to one stable `fixture-api` Vapor instance and removes
credentials and identity headers first. It does not log request bodies or
sensitive headers. Inspect Worker logs and traces through Cloudflare
Observability after a release. A container can cold-start after its ten-minute
idle sleep.

For the complete API, manually redeploy a known-good commit SHA so Wrangler
rebuilds and releases its matching Worker and Container image. D1 migrations
are forward-only: the chosen revision must remain compatible with the current
schema. `cd Cloudflare && npx wrangler rollback <version-id> --name dont-unplug-that-api`
rolls back only the Worker and is safe only when both the active Container image
and D1 schema are compatible.

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
