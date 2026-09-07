# Daylight website design QA — September 7, 2026

final result: passed

Scope: website only. Native app source changes are tracked separately in `../Design/native-qa.md`.

## Evidence

- Visual truth: `../Design/daylight-selected.png` (1648 × 954 image, website frame cropped at x=4, y=2, width=1143, height=949).
- Reference normalization: proportional resize of the website crop to 1440 × 1196, saved as `../Design/qa/reference-website.png`. No stretching or device chrome included.
- Final browser capture: `../Design/qa/website-desktop-final.png`, 1440 × 1196 CSS viewport and screenshot pixels (1 screenshot pixel per CSS pixel), in the Codex in-app browser.
- Initial comparison: `../Design/qa/comparison-website.png`, common 1440 × 1100 region of both images, side by side.
- Final full-view comparison: `../Design/qa/comparison-website-final.png`, both frames at 1440 × 1196.
- Focused heading / copy / CTA comparison: `../Design/qa/comparison-typography.png`.
- Responsive capture: `../Design/qa/website-mobile.png`, 390 × 844 CSS viewport and screenshot pixels. The source board's mobile panel is the native app, not the mobile website; the mobile website is a responsive adaptation of the desktop design.
- Interaction capture: `../Design/qa/website-mobile-expanded.png`.
- Default state: amplifier selected, example detail disclosure closed, page at top.

## Findings and comparison history

1. Initial [P2] desktop hierarchy: headline, supporting type and CTA were smaller than the source. Fixed the desktop heading scale (92px cap), supporting copy (28px cap), CTA type (24px) and height (64px). Restored the source's overall photograph position and typography hierarchy.
2. [P2] closing the example removed the focused close button. Fixed by restoring keyboard focus to the caption disclosure control; verified `document.activeElement` is the caption button after closing.
3. Post-fix full-view and focused comparisons reviewed. No remaining P0/P1/P2 findings. Main content, whitespace, headline wrapping and photo-led composition match the selected direction.

## Five fidelity surfaces

- Typography: self-hosted Outfit variable, navy text, medium-weight headings and readable supporting text. Similar rounded humanist character to the generated reference; font glyphs are not an exact match to a raster mock. Responsive heading and copy wrapping checked.
- Spacing/layout: white base surface, horizontal wordmark/nav, generous hero spacing, wide 3:1 photograph, slim caption and privacy line. Responsive lower sections use one column. 320, 390, 768 and 1440 widths have no horizontal overflow. Pins remain registered to the full, uncropped photograph at every size.
- Color/tokens: cobalt `#1249dc`, navy `#0b153c`, muted slate `#546789`, pale blue `#eef4fc`, white base. Semantic caution copy uses a separate dark ochre. Focus rings and selected pins remain visible.
- Images/icons: generated standalone audio photograph matches subject, crop and daylight art direction. Second welcome photograph matches the app still life and is reused below the fold. Loaded image dimensions confirmed in browser. Phosphor supplies standard icons; its plug silhouette differs slightly from the conceptual circular wordmark. This is a P3 refinement, not custom drawn substitute artwork.
- Copy/content: hero and primary CTA preserved. Added plainly labeled interactive example, explanatory sections and accurate privacy details. No fabricated availability, testimonials, upload capability, or safe-to-unplug guarantee. Native-only on-device analysis remains clear.

## Browser interactions and checks

- All three numbered pins select corresponding items; caption and expanded explanation update.
- Unplugging-impact disclosure reveals the selected item's impact and hides again.
- Close control collapses detail and restores focus.
- Keyboard Enter activates pins and disclosure controls.
- Main CTA and How it works anchor navigate to the explanation section; Privacy and footer anchors navigate correctly.
- 390px and 320px narrow-screen checks; 768px tablet and 1440px desktop checks.
- Both images loaded successfully and computed heading font is Outfit Variable.
- Browser error/warning log checked: none.
- Production build passed. Four bundled static-hosting adapter tests passed.
- Reduced-motion styles disable smooth scrolling and transitions. Visible focus and accessible names present.

## Follow-up limits

- Screen-reader output and browser/device combinations beyond the Codex in-app browser have not been exhaustively tested.
- The sample guide is static illustrative data; no browser AI or photo upload is implied.
- Native simulator and Android visual verification are not covered by this pass.
