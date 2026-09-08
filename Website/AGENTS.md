# Prototype Instructions

Run the local server yourself and open the preview in the browser available to this environment. Do not give the user server-start instructions when you can run it.

Before making substantial visual changes, use the Product Design plugin's `get-context` skill when the visual source is unclear or no longer matches the current goal. When the user gives durable prototype-specific design feedback, preferences, or decisions, record them in `AGENTS.md`.

When implementing from a selected generated mock, treat that image as the source of truth for layout, component anatomy, density, spacing, color, typography, visible content, and hierarchy.

Build app UI in `src/`. Keep `.openai/hosting.json`, `worker/index.js`, `scripts/prepare-sites-build.mjs`, and `tests/sites-worker.test.mjs` intact so the same local prototype can be handed to Sites. Before a Sites handoff, run `npm run build` and `npm run test:sites`; the build must leave `dist/client/index.html`, `dist/server/index.js`, and `dist/.openai/hosting.json`.

## Accepted direction — September 7, 2026

Use Daylight (design 2), the exact reference at `../Design/daylight-selected.png`, for both the site and native app. White, cobalt blue, midnight navy, humanist sans, generous spacing, natural daylight product photos. Avoid industrial styling. Design 1 is archived for a different future project, not an alternate theme for this product.

## Website framework — September 7, 2026

Use Astro for the website, not React. Render static HTML and use a small browser script for the example interactions. Preserve the accepted Daylight design.

Use the Daylight upright plug/open-circle brand mark from `../Design/Brand/daylight-mark.svg` for the website and app icons. Cobalt blue on white, never a black background.
