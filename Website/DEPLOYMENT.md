# Production deployment — September 7, 2026

URL: https://dontunplugthat.com/
Cloudflare Worker: `dont-unplug-that-website`
Version: `5eb24fad-ac61-43a1-89c1-4e4ed1b76ca8`
Custom domain enabled: `dontunplugthat.com`

Deployed directly with Wrangler using `wrangler.jsonc`. Website build, four static adapter tests and deployment dry run passed. Domain and managed certificate were attached successfully.

Verification: public Cloudflare DNS returns A records for the domain. HTTPS request to the resolved Cloudflare address, with the domain used for SNI and certificate verification, returns 200. Production JS, CSS, two photographs and primary font match the local built bytes by SHA-256.

The local network resolver had cached the prior empty DNS answer (SOA negative cache initially about 30 minutes). This prevented the in-app browser from opening the public domain immediately. Local browser visual and interaction QA is recorded in `design-qa.md`; no fresh production browser visual pass is claimed. No local DNS settings were changed.

Future website updates: `npm run deploy` from `Website/` after verification. This deploys only the website; the native app and API are separate.

## Astro migration — September 7, 2026

Deployed version `60b26256-92ed-4d87-be94-8b99ece4701f` directly with Wrangler. Astro now emits static HTML with a small TypeScript interaction script; React is removed. The Daylight design and TestFlight link are preserved. Build and all four adapter tests passed. Local browser checks covered annotation selection, keyboard toggles, focus restoration, and impact reset. Before/after screenshots matched visually.

Production HTTPS returned 200 using the resolved Cloudflare address with certificate verification. HTML matches the local build after excluding Cloudflare's injected challenge script; CSS matches byte for byte. The TestFlight URL is present in the live HTML.
