# Daylight icon

The upright plug inside an open circle is redrawn as a vector from `../daylight-selected.png`. Use cobalt `#1249dc` on white, with no black background. `daylight-mark.svg` is the source of truth.

Run `node Design/Brand/generate-icons.mjs` from the repo root after installing Website dependencies. This updates the existing iPhone/iPad/App Store catalog, Android legacy/adaptive/themed assets, the native header logo, web favicons, Apple touch icon, web manifest icons, and store artwork. Android's monochrome layer is a transparent system-tint mask; its normal background is white.

Verification: all iOS PNG dimensions match their asset-catalog entries and are opaque. The normal icon has no black pixels. Android foreground artwork fits inside the central 66dp safe circle. Website build and four adapter tests pass; the new header was visually checked in-browser. Android `:app:assembleDebug` passed and APK signature verification passed. An iOS app build has not been run for this change.

Android icon build SHA-256: `c6fbe6c39307886232e5929a2f3d1e3f7cc25b4bfc42447738af7c97f4898db7`.

The website was deployed to Cloudflare version `ecdf6e7f-6a35-4e3d-9f4c-00456f787877`. Its live favicon matches the local source byte for byte.
