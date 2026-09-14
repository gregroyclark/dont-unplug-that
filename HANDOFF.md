# Don't Unplug That — session handoff

Updated 13 September 2026. These notes are local project context, not permission
to build, push, deploy, or access another account's conversations or credentials.

- Objective and completion condition: let fresh Codex sessions, including sessions
  signed in to another ChatGPT account on this Mac, use the same checkout and
  project context without depending on this conversation's memory.
- Project path and current branch: `/Users/gregclark/Code/personal/dont-unplug-that`;
  `master`, tracking `origin/master`. Inspected HEAD:
  `f85b14d59f905f9b79d39cc54c09c1b2a735b3c1`. Recheck Git state before editing.
- Current state and relevant files: the checkout was clean before adding this
  handoff and `AGENTS.md`. `README.md` maps the native app, Astro website, shared
  Swift models, Vapor fixture server, and Cloudflare Worker. `.github/DEPLOYMENT.md`
  records store identifiers, configuration, and delivery prerequisites. No remote
  fetch or build was performed during this continuity setup.
- Decisions and constraints: native Swift/Skip analysis on iOS/Android; local-first
  guide history; optional Better Auth accounts with D1 metadata and private R2
  photo derivatives. Keep Vapor and its Container; no cloud-AI fallback or public
  photo sharing. Greg's current agreement prohibits GitHub pushes and destructive
  database operations. Do not create arbitrary codex branches. Native builds and
  external releases require explicit authorization. Earlier conversation release
  approvals do not waive the current agreement.
- Verification performed and results: located the moved checkout, confirmed
  `master`/HEAD and a clean starting tree, and restored the missing old-path
  compatibility symlink. Updated the app-server project's roots to the canonical
  checkout through `project/update`; a cached sidebar may still show the old path,
  which now resolves to the same Git repository. The saved Codex project is
  `speedrun-vibes` (legacy ID
  `34e0321a-4d83-4b26-aadb-16e05c17a29c`, app-server ID
  `01a072d0-7835-71d0-8a4f-8ea6c2341c1d`). Account-specific history and authentication
  have not been copied or modified. The prior project registration is recorded at
  `/Users/gregclark/.codex/project-handoffs/dont-unplug-that-20260913/project-before.json`.
  Verified project listing recognizes the repository through the compatibility
  path, and `git diff --check` passes. Another account's sidebar was not tested.
- Outstanding work or blocker: Android/Google Play readiness was the last
  substantive task in this conversation. The APK inspected on 8 August contained
  the full app/Swift runtime only for x86_64, not ARM64. Later commits include
  Android support work, so do not assume that old artifact describes today's
  source. Current native and Play workflows still select `macos-15-intel`; inspect
  the current artifact's complete native-library contents before declaring the
  issue resolved. Google Play's package remains provisional in deployment docs;
  confirm the listing and account-verification status. Gemini Nano eligibility is
  separate from successful app launch. No current device/build/release result was
  established in this continuity-only task.
- Existing authorization and actions still requiring approval: this request
  authorizes local Codex project availability and handoff setup, not app changes,
  native builds, commits, GitHub pushes, workflow dispatches, or store uploads.
- Next concrete action: start a fresh session in this checkout and ask it to read
  `AGENTS.md` and `HANDOFF.md`, then specify the next task. For Play readiness,
  begin with a read-only inspection of the latest APK/AAB and current workflows;
  request build authorization only when a native build is needed. If another
  account does not show the project, add this canonical folder as a local project
  using the app's project controls. Both registrations must use this same checkout.
