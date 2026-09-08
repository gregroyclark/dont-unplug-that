# Don’t Unplug That — Daylight website

A static Astro landing page with a small TypeScript script for the interactive example, built from the selected design in `../Design/daylight-selected.png`. Includes a keyboard-accessible example guide with selectable photo annotations, evidence notes, and expandable unplugging impacts. The example is illustrative, not live AI analysis. Native photo analysis, account sync and saved guides remain in the existing SwiftUI / Skip app.

## Local preview

```sh
npm install
npm run dev -- --host 127.0.0.1 --port 4173
```

## Verification and packaging

```sh
npm run build
npm run test:sites
```

Build output: `dist/client/`. The starter's optional Sites worker and metadata are retained in `dist/server/` and `dist/.openai/`. Nothing is deployed by building. Production deployment is explicit.

## Design assets

The two still-life photographs were generated for this design. Hero: `public/images/living-room-audio.webp`; welcome: `public/images/welcome-setup.jpg`. The welcome photograph is also packaged with the native app. Font is self-hosted [Outfit via Fontsource](https://fontsource.org/fonts/outfit); icons use [Phosphor](https://phosphoricons.com/). No visitor photo upload or third-party analytics is implemented on this page.

See `design-qa.md` for visual comparison, browser checks, and known limits.

## Cloudflare production hosting

Production domain: https://dontunplugthat.com/

The assets-only Cloudflare Worker `dont-unplug-that-website` serves `dist/client/`.
`wrangler.jsonc` declares the custom domain; Cloudflare manages its DNS and HTTPS
certificate. The native API remains the separate `dont-unplug-that-api` service.
This deployment does not use the optional Sites adapter.

To deploy a website update from this directory:

```sh
npx wrangler whoami
npm run deploy
```

`npm run deploy` builds the website and uploads it directly to Cloudflare. It does
not use GitHub. No database or API service deployment is part of this command.


## CI/CD isolation

The website's pipeline is `.github/workflows/website.yml`. It builds/tests on
website PRs and deploys successful website pushes through `website-production`.
Native and API workflows use separate path filters, toolchains and release
credentials. See `../.github/DEPLOYMENT.md` for the CI secret required before the
new workflow can deploy.
