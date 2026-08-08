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
Cloudflare/ Worker glue, generated bindings, and pinned deployment tooling
.github/   Pull-request validation and store/Cloudflare delivery workflows
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

### Vapor API on Cloudflare Containers

The existing Vapor executable is deployed unchanged in one Cloudflare Container.
The TypeScript Worker only forwards the original request to the stable
`fixture-api` instance; it does not implement product routes or validate API
payloads. Cloudflare Containers are generally available on the Workers Paid
plan. This first deployment intentionally has one `lite` instance, no outbound
container internet access, ephemeral disk, and a ten-minute idle sleep period.

Local prerequisites are Node.js 22+, Docker with its daemon running, and the
Swift toolchain used by the image. From the repository root:

```sh
cd Cloudflare
npm ci
npm run types:generate
npm run check
npm run config:check
cd ..
docker build --platform linux/amd64 --tag dont-unplug-that-server:local .
docker run --rm -p 8080:8080 dont-unplug-that-server:local
```

Then verify the direct Vapor contract in another terminal:

```sh
curl --fail-with-body http://127.0.0.1:8080/health
curl --fail-with-body -H 'content-type: application/json' \
  --data '{"base64EncodedImage":"ZmFrZQ==","mediaType":"image/jpeg"}' \
  http://127.0.0.1:8080/v1/guides/analyze
```

`npm run config:check` uses Wrangler's credential-free deploy dry run, which
still builds the configured image and therefore needs Docker. Re-run
`npm run types:generate` after changing `wrangler.jsonc`; the generated
`worker-configuration.d.ts` is committed and checked in CI.

## Delivery

Pull requests validate the shared models, server, and mobile app. Manual GitHub
Actions workflows package and submit builds to TestFlight and the Google Play
internal track after the corresponding store apps and repository secrets are
configured.

Store submission, processing, tester-group assignment, and successful installation on physical devices are separate acceptance gates. A green workflow alone does not prove on-device delivery.

Cloudflare release runs through **Deploy Vapor API to Cloudflare** whenever a
commit reaches `main` or `master`. The same workflow can be run manually with
an immutable, full 40-character commit SHA. Configure the
`cloudflare-production` protected environment before enabling the first
release. The job uses an immediate single-instance Container rollout, waits for
Cloudflare to report the named image and version ready, records the source SHA
and Wrangler deployment data, takes the URL reported by Wrangler rather than
assuming a workers.dev subdomain, and runs public `/health`, fixture analyze,
and blank-image `400` smoke tests. First-time provisioning can take several
minutes. View Worker logs and traces in Cloudflare Observability; do not add
image bodies or sensitive headers to logs.

For a full release rollback, manually redeploy a known-good commit SHA under a
separately approved change; that rebuilds the matching Worker and Container
image together. `cd Cloudflare && npx wrangler rollback <version-id> --name dont-unplug-that-api`
rolls back only the Worker deployment and must be used only when the active
Container image is known to be compatible.
