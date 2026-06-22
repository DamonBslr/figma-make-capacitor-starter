---
name: figma-make-to-capacitor
description: >-
  Initial transformation of a Figma Make repository into a production-ready
  Capacitor mobile app. Use when bootstrapping a NEW mobile app from a Figma
  Make (React web) export: it sets up the monorepo, splits the Figma UI into a
  presentation layer, scaffolds an auth/data/API logic layer, wraps everything
  in Capacitor for iOS/Android, and wires OTA live updates. Trigger on requests
  like "turn this Figma Make repo into an app", "bootstrap the Capacitor app
  from Figma", or the /init-from-figma command. Do NOT use for incremental
  design changes after the app exists — that is a separate sync flow.
allowed-tools: Bash Read Write Edit Glob Grep
---

# Figma Make → Capacitor: Initial Transformation

Run this ONCE per app, to convert a Figma Make export into a production monorepo.
It is a bootstrap, not an update. If the monorepo already exists, stop and tell
the user this skill is for first-time setup only.

## Inputs (ask only for what is missing)
- Figma Make repo URL, or a path to an already-cloned copy.
- App display name, e.g. `Acme`. **Must be confirmed available in App Store Connect
  before use** — see Step 0.
- Bundle / app id, e.g. `com.acme.app`. **Must be registered in Apple Developer
  Portal and claimed in App Store Connect before use** — see Step 0.
- OTA provider — default `capgo`.
- Package manager — default `pnpm` (bun and npm supported). Export `PM` before
  running the scripts, e.g. `export PM=pnpm`.

## Target architecture
Read `references/architecture.md` in full before moving any code. In short:

- `packages/ui` — presentation layer. Figma-derived screens and components.
  Dumb: props in, callbacks out. NO data fetching, auth, storage, env, or
  business logic. **This is the only directory the future Figma sync writes to.**
- `packages/core` — logic layer. Auth, data clients, API, domain types, hooks.
  Hand-written. The Figma sync never touches it.
- `apps/mobile` — the Capacitor app. Composes `ui` + `core`, owns routing/shell,
  `capacitor.config.ts`, the native `ios/` and `android/` projects, and OTA init.

## Starter detection (check before step 1)

Check whether the repo was cloned from `figma-to-capacitor-starter`:

```bash
test -f packages/ui/package.json && test -f tsconfig.base.json && echo "starter"
```

**If starter detected:** steps 3, 8, and 9 are already done — skip them.
The skeleton, `CLAUDE.md`, and `App.tsx` with `notifyAppReady` are pre-baked.
Proceed directly from step 1 → 2 → 4 → 5 → 6 → 7 → 10 → 11.

**If no starter:** follow all 11 steps — the scaffold script creates the skeleton
from scratch. Both paths produce the same result.

## Procedure

### Step 0 — App Store pre-flight (do this BEFORE choosing identifiers)

Before writing a single line of code or picking a bundle ID, the app name and
identifier must be reserved in the relevant store(s). If skipped, the user can
spend hours on a bundle ID that is already taken, or ship a build under a name
that App Store Connect rejects at upload time.

**iOS (App Store Connect)**
1. Sign in to [App Store Connect](https://appstoreconnect.apple.com) → My Apps → **+** → New App.
2. Select **iOS** (or universal). Enter the **app name** — this is what appears
   on the App Store. If the name is taken you'll see an error immediately; resolve
   it before continuing.
3. Enter the **Bundle ID** you plan to use (it must already exist, or be creatable,
   in your Apple Developer Program portal → Certificates, Identifiers & Profiles).
   Register the Identifier there first if it doesn't exist yet.
4. Complete the rest of the New App form (SKU, primary language) and click Create.
   You do not need metadata or screenshots at this stage — you just need the record
   to exist so your bundle ID is locked and the name is claimed.
5. Note the numeric **Apple ID** (App ID) shown on the App Information page — you
   will need it for TestFlight and for setting `apple_id` in Fastlane or `eas.json`.

**Android (Google Play Console)** *(if targeting Android)*
1. Sign in to [Google Play Console](https://play.google.com/console) → All apps → **Create app**.
2. Enter the app name, select app type and category, agree to policies, and click
   Create app. The package name is set later when you upload the first AAB/APK —
   but decide it now and use it consistently, because it cannot be changed after
   the first upload.

**Do not proceed to step 1 until both of these are done for every target platform.**

---

1. **Clone source, read-only.** Clone the Figma repo into `.figma-src/` at the
   repo root. It is upstream source: never edit it, never push to it. (It is
   gitignored by the scaffold.)

2. **Inventory.** Identify the build tool and entry point, the router, where
   screens vs shared components live, and EVERY place that mixes non-UI concerns
   into components: `fetch`/axios calls, Supabase/API clients, `localStorage`/
   `sessionStorage`, env/secret reads, auth flows, business rules. Record findings
   in `TRANSFORMATION_REPORT.md`. This inventory drives step 5.

3. **Scaffold** *(skip if starter detected).* Run `scripts/scaffold_monorepo.sh`
   from the repo root to create the workspace skeleton, base TS config, gitignore,
   and the three layers.

4. **Place the UI.** Move screens and presentational components into
   `packages/ui/src`; move the app entry, router, and providers into
   `apps/mobile/src`. `packages/ui` must compile without importing any concrete
   implementation from `packages/core` — it may import shared TYPES/interfaces only.

   **Fonts — mandatory.** Figma Make outputs `@import url('https://fonts.googleapis.com/...')`
   in CSS. Never ship that. Loading Google Fonts at runtime sends user IPs to Google,
   which violates GDPR (Germany has case law on this specifically). Replace every
   Google Fonts CDN reference with locally-bundled Fontsource packages:
   1. Identify every font family in the `@import url(...)` string.
   2. Install `@fontsource-variable/<family-name>` (preferred) or `@fontsource/<family-name>`
      in `packages/ui`. Use the `-variable` variant when a variable font exists.
   3. In `packages/ui/src/styles/fonts.css`, replace the `@import url(...)` lines with
      `@import '@fontsource-variable/<family-name>/index.css'` (add `-italic.css` or
      `wght-italic.css` variant if italic weights were requested).
   4. Do NOT add a `<link>` to `fonts.googleapis.com` in `index.html` — that has the
      same privacy problem as the CSS `@import url(...)`.
   5. Note each font package installed in `TRANSFORMATION_REPORT.md`.

5. **Separate logic from presentation** (the core judgment step). For each concern
   found in step 2: move it into `packages/core` behind a typed interface (a
   service or a hook), and replace the inline version in the UI with a prop or
   hook call. Provide a stub implementation returning typed mock data, marked
   `// TODO(human-review): wire real backend`. NEVER fabricate real auth, secrets,
   tokens, or data-access logic. List every stub in the report.

6. **Add Capacitor + OTA.** From the repo root, run
   `scripts/add_capacitor.sh "<AppName>" "<app.id>" "<webDir>"`. It fills the
   three tokens in the pre-baked `capacitor.config.ts`, installs Capacitor core +
   CLI, adds iOS + Android, and installs the OTA plugin plus a baseline of native
   plugins. `<webDir>` is the web build output dir (e.g. `dist`).

7. **Adapt web-only patterns for native.** Safe-area insets; hardware back button
   via `@capacitor/app`; replace web storage with `@capacitor/preferences` (inside
   `packages/core`, not the UI); status bar and splash screen. Note each change in
   the report.

8. **Wire OTA** *(skip if starter detected — `App.tsx` already has it).* Call
   `CapacitorUpdater.notifyAppReady()` once the app is ready. If starting from
   scratch (no starter), add it to the top-level `App` component. Leave channel
   creation and bundle upload to the provider's CLI/dashboard and record that as a
   manual step — do not invent credentials or CLI flags.

9. **Install project rules** *(skip if starter detected — `CLAUDE.md` already at
   root).* Copy `assets/CLAUDE.md` to the repo root so the durable rules travel
   with the project.

10. **Build + sync.** Build the web bundle and run `cap sync`. Resolve type and
    build errors. Do NOT open native IDEs, sign, or submit to any store.

11. **Finalize the report.** `TRANSFORMATION_REPORT.md` must list: what moved
    where, every stub awaiting a human, every web-only adaptation made, and the
    remaining manual steps (OTA channel setup, native signing, store submission).

## Guardrails
- `.figma-src/` is read-only upstream. Never modify or push to it.
- Generated UI code is not secure by default. Auth, tokens, and data access are
  STUBS for human review — never fabricate them to make things "work".
- Stop at the report. A human reviews before any native build or store submission.
- This skill bootstraps. It is never the right tool for an incremental redesign.
