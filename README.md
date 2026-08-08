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
Guide history is local-first. An optional account syncs guides and private,
metadata-stripped photo derivatives across the user's devices; cloud AI and
public sharing remain out of scope.

## Native app, small services

- `App/` is a Skip Fuse app. Its SwiftUI code runs on iOS and is compiled for Android by Skip.
- `Shared/` contains the `Codable` guide contract shared by the app and server.
- `Server/` is a Vapor API with a deterministic development fixture; production
  photo inference does not pass through it.
- `Cloudflare/` is a TypeScript Worker. Better Auth handles Apple and Google
  sign-in, D1 stores account and guide metadata, and private R2 objects hold
  sync-only photo derivatives.

The analysis experience remains native Swift/Skip on both platforms. Vapor is
kept as the fixture API behind a Cloudflare Container; it is not an auth or
photo-storage service.

Mobile builds use the canonical Worker host
`https://dont-unplug-that-api.gregroyclark.workers.dev` from shared Swift code,
so the same endpoint ships on iOS and Android. Local development can override
it with `DUT_API_BASE_URL`.

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
6. Save the guide locally and, when signed in, sync it privately across devices.

The server fixture keeps the contract testable without becoming a cloud fallback
for private photos.

## Local development

Requirements:

- macOS with Xcode 27 or newer for multimodal Apple Foundation Models
- Swift 6.4 or newer for the iOS 27 model integration
- Skip 1.9 or newer with its native Android toolchain
- Android Studio or the Android SDK for Android builds

Each package includes its own build instructions. No store credentials or AI keys belong in the repository.

### Cloudflare sync and Vapor fixture API

The Worker owns optional account and sync routes. Better Auth uses direct D1,
and guide photos are private R2 objects reachable only through authenticated
Worker routes. Sync uses explicit revisions and tombstones so concurrent edits
surface as conflicts instead of silently overwriting a guide. The existing
Vapor executable is deployed unchanged in one Cloudflare Container and receives
only exact `/health` and `/v1/guides/analyze` fixture requests with credentials
stripped. Cloudflare Containers require the Workers Paid plan.

Local prerequisites are Node.js 22+, Docker with its daemon running, and the
Swift toolchain used by the image. From the repository root:

```sh
cd Cloudflare
npm ci
npm run types:generate
npm run check
npx wrangler d1 migrations apply DB --local
npm run config:check
cd ..
docker build --platform linux/amd64 --tag dont-unplug-that-server:local .
docker run --rm -p 8080:8080 dont-unplug-that-server:local
```

Then verify the direct Vapor contract in another terminal:

```sh
curl --fail-with-body http://127.0.0.1:8080/health
curl --fail-with-body -H 'content-type: application/json' \
  --data '{"photos":[{"base64EncodedImage":"ZmFrZQ==","mediaType":"image/jpeg"}]}' \
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

Cloudflare release runs through **Deploy API to Cloudflare** whenever a
commit reaches `main` or `master`. The same workflow can be run manually with
an immutable, full 40-character commit SHA. Configure the
`cloudflare-production` protected environment before enabling the first
release. Provision the D1 database and private R2 bucket, apply the committed
migrations, and configure the Better Auth and OAuth secrets described in
`.github/DEPLOYMENT.md`. The job applies pending D1 migrations, uses an immediate
single-instance Container rollout, waits for
Cloudflare to report the named image and version ready, records the source SHA
and Wrangler deployment data, takes the URL reported by Wrangler rather than
assuming a workers.dev subdomain, and runs public `/health`, fixture analyze,
and blank-image `400` smoke tests. First-time provisioning can take several
minutes. View Worker logs and traces in Cloudflare Observability; do not add
image bodies or sensitive headers to logs.

For a full release rollback, manually redeploy a known-good commit SHA; that
rebuilds the matching Worker and Container image together. D1 migrations are
forward-only, so a rollback must remain compatible with already-applied schema.
`cd Cloudflare && npx wrangler rollback <version-id> --name dont-unplug-that-api`
rolls back only the Worker deployment and is appropriate only when the active
Container image and D1 schema remain compatible.
