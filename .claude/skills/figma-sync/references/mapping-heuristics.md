# Mapping heuristics: upstream diff → packages/ui (+ flags)

How to turn an upstream Figma Make diff into a clean, reviewable mapping. The goal
is a per-file decision a human can scan and trust: each changed upstream file lands
in exactly one bucket, and nothing slips past the `packages/ui` boundary.

This is the inverse of init's discovery: init split one tree into three layers; sync
re-applies upstream changes into the layer that already owns them. Read
`../../figma-make-to-capacitor/references/architecture.md` for the layer rules first.

## The buckets (one per changed file)

- **ui-only** — styling, layout, copy, a presentational component added / removed /
  renamed, a new pure screen. Belongs entirely in `packages/ui/src`. This is the
  common case and the only one that ships via OTA with no further work.
- **ui+stub** — the upstream change edits a region that the initial transformation
  pulled out into `packages/core` (a `fetch`/HTTP call, auth flow, `localStorage`,
  env read, or business rule). The presentational delta lands in `packages/ui`; the
  logic delta becomes a `// TODO(human-review)` note or stub in `packages/core` —
  NEVER a real implementation. A human (or `/wire-supabase`) reconciles the logic.
- **backend-follow-up** — a genuinely new capability (a new data-backed screen, a new
  persisted domain shape) with no existing stub behind it. Add the presentational
  component to `packages/ui` + a typed stub in `packages/core` tagged
  `// TODO(human-review)`, and list it under "Backend follow-ups" for `/wire-supabase`
  to spec later.
- **delete / rename** — mirror into `packages/ui` and note the
  `packages/ui/src/index.ts` barrel update it forces.
- **ignore** — upstream files that never belonged in `packages/ui`: Figma build
  config, lockfiles, the app entry / router / providers (those live in `apps/mobile`,
  hand-owned), or anything already adapted for native. Record *why* it's ignored so
  the reviewer sees it was considered, not missed.

## Deciding the bucket

1. Does the changed upstream path correspond to a file we currently have under
   `packages/ui/src`? If yes and the change is purely presentational → **ui-only**.
2. Does the changed region overlap a concern the init extracted? Detect it:
   `grep -rn "TODO(human-review)" packages/core/src` for the init-era stubs, then
   check whether the upstream-changed screen is the one that consumes the matching
   `@app/core` hook. Overlap → **ui+stub**.
3. Is it a new screen/component with data needs and no stub behind it →
   **backend-follow-up**.
4. Is it an app-entry / router / build-config / native-adapted file → **ignore**
   (with a reason).

When unsure between ui-only and ui+stub, treat it as **ui+stub** — a spurious
`// TODO(human-review)` note is cheap; silently re-importing logic into `packages/ui`
breaks the boundary.

## Copy vs. adapt (for ui-only and the UI part of ui+stub)
- **Copy near-verbatim** when our `packages/ui` file still mirrors the Figma file's
  structure (init didn't have to move much out of it). Re-apply the upstream hunk.
- **Adapt by hand** when init moved logic out of that file — the line numbers won't
  match. Port the *presentational* intent of the hunk and leave the prop/hook seam
  intact. The exported component signature must not change unless the design genuinely
  changed the props the screen needs (and then it's a ui+stub or follow-up, because
  the shell in `apps/mobile` feeds those props).

## Fonts (mandatory, same as init)
If the diff reintroduces `@import url('https://fonts.googleapis.com/...')` or a
`<link>` to `fonts.googleapis.com`, do not ship it (runtime Google Fonts leaks user
IPs — GDPR). Convert each family to `@fontsource-variable/<family>` (or
`@fontsource/<family>`) and note it in the plan.

## Sanity checks before writing the plan
- Every changed file in `git diff --stat` appears in exactly one bucket (none dropped,
  none double-counted).
- Nothing in the plan targets a path outside `packages/ui` except the explicitly
  flagged `// TODO(human-review)` stubs in `packages/core`.
- No exported `packages/ui` signature change is proposed without a matching note
  (ui+stub or follow-up) explaining how the shell feeds the new prop.
- Every backend-follow-up names the stub it adds and is handed to `/wire-supabase`.
