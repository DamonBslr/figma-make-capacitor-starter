---
name: figma-sync
description: >-
  Incremental design sync from the Figma Make repo into an already-transformed
  Capacitor app. Use when the design has evolved in Figma Make AFTER the app
  exists and you need to pull those changes into packages/ui without touching
  hand-written backend logic. It anchors on the last-synced upstream commit
  (FIGMA_SOURCE.json), diffs the Figma repo, writes a reviewable SYNC_PLAN.md,
  stops for approval, then applies UI-only changes and opens a PR. Trigger on
  "sync the Figma changes", "pull the latest design", "update from Figma Make",
  or the /sync-figma command. Do NOT use for first-time bootstrap — that is
  figma-make-to-capacitor (run once). This skill is for updates only.
allowed-tools: Bash Read Write Edit Glob Grep
---

# Figma Make → App: Incremental Design Sync

Run this REPEATEDLY, every time the design evolves upstream. It is an update, not
a bootstrap. If `packages/ui` does not exist yet, stop and tell the user to run
`figma-make-to-capacitor` (`/init-from-figma`) first — this skill assumes the
monorepo and the initial transformation already exist.

The three-layer architecture exists precisely so design changes can be re-synced
forever without touching backend logic. This skill is the tool that does it
safely: it writes ONLY into `packages/ui` (plus `// TODO(human-review)` stubs in
`packages/core`), never into real `packages/core` logic, `apps/mobile`, or
`.figma-src/`.

Read `references/mapping-heuristics.md` (how to classify each upstream change) and
`references/sync-plan-template.md` (the exact `SYNC_PLAN.md` shape) before mapping.

## Inputs (ask only for what is missing)
- Branch to sync from — default `main`. The Figma repo URL is read from
  `FIGMA_SOURCE.json` (or, on a baseline run, asked for / read from the existing
  `.figma-src/` remote).

## The anchor: FIGMA_SOURCE.json
A committed file at the repo root that records which upstream Figma Make commit the
app currently reflects. It is the single source of truth for "where we are":

```json
{
  "repo": "https://github.com/acme/figma-make-export",
  "branch": "main",
  "synced_commit": "a1b2c3d4...",
  "synced_at": "2026-06-21",
  "last_sync_pr": 42
}
```

## Procedure

### 1. Locate the anchor
Read `FIGMA_SOURCE.json` at the repo root.

- **If it exists:** use `synced_commit` + `branch` + `repo` as the diff base. Go to step 2.
- **If it is missing:** STOP and tell the user to set the anchor first with
  `/set-figma-source` (it clones/inspects `.figma-src/`, verifies the commit the
  current `packages/ui` reflects, and writes `FIGMA_SOURCE.json`). Pinning to the
  commit the app was actually transformed from — rather than upstream HEAD — is what
  makes the first diff meaningful, so it is a deliberate human-confirmed step, not
  something this skill guesses. Do not attempt to map anything without the anchor.

### 2. Fetch upstream (read-only)
`.figma-src/` is read-only upstream source: never edit it, never push to it, never
commit inside it. Operate only with read commands:

- `git -C .figma-src fetch origin`
- `git -C .figma-src log --oneline <synced_commit>..origin/<branch>` — enumerate the
  new commits since the anchor.
- If that range is empty (`synced_commit` == `origin/<branch>` HEAD): report
  **"Already up to date"** and STOP.
- `git -C .figma-src diff --stat <synced_commit>..origin/<branch>` — the changed-file
  overview.
- `git -C .figma-src diff <synced_commit>..origin/<branch> -- <path>` — per-file
  patches for the files you need to map.

Capture `from_commit` (= `synced_commit`) and `to_commit` (= the resolved
`origin/<branch>` SHA) for the plan header.

### 3. Map each changed upstream file to a layer
For every changed file in the diff, classify it per `references/mapping-heuristics.md`:

- **ui-only** — styling, layout, copy, a new/removed/renamed presentational
  component. Maps directly into `packages/ui/src`. Prefer a near-verbatim copy when
  our `packages/ui` file still mirrors the Figma structure; adapt by hand when the
  initial split moved logic out of that file.
- **ui+stub** — the upstream change edits a region we extracted to `packages/core`
  during init (a `fetch`/auth/storage/business-rule region). The presentational part
  lands in `packages/ui`; the logic part becomes a `// TODO(human-review)` note/stub
  in `packages/core`, NEVER a real implementation.
- **backend-follow-up** — a new screen/component that implies a backend capability
  that doesn't exist yet. Add the presentational component to `packages/ui` + a typed
  stub in `packages/core` tagged `// TODO(human-review)`, and record a follow-up for
  `/wire-supabase` (see step 4).
- **delete / rename** — mirror the deletion/rename into `packages/ui`, and note the
  `packages/ui/src/index.ts` barrel update it requires.
- **ignore** — upstream-only files that never belonged in `packages/ui` (Figma build
  config, the app entry/router that lives in `apps/mobile`, etc.). Record why.

Use the separation pattern from
`../figma-make-to-capacitor/references/architecture.md` (the "before/after" refactor).
To detect ui+stub vs ui-only, grep the init-era extractions:
`grep -rn "TODO(human-review)" packages/core/src` and match the upstream-changed
screen against the `packages/core` hook it consumes.

**Fonts guardrail (mandatory).** If the upstream diff reintroduces an
`@import url('https://fonts.googleapis.com/...')` or a `<link>` to `fonts.googleapis.com`,
do NOT ship it (runtime Google Fonts leaks user IPs — GDPR). Convert each family to a
locally-bundled `@fontsource-variable/<family>` (or `@fontsource/<family>`) import, as
in init step 4. Note it in the plan.

### 4. Write SYNC_PLAN.md (the gate artifact)
Write `SYNC_PLAN.md` at the repo root following `references/sync-plan-template.md`:
- Header: `from_commit`, `to_commit`, commit count, branch, date, and a **Boundary
  check** line asserting nothing will be written outside `packages/ui` except the
  flagged `// TODO(human-review)` stubs.
- The per-file table: `upstream file | change type | classification | target path in
  packages/ui | notes`.
- A separate **Backend follow-ups** block listing each `backend-follow-up` with the
  stub it adds and the `/wire-supabase` handoff (it will spec the new stub later).

### 5. STOP at the sync-review gate
Present the plan to the user. **Do not modify any file yet** (other than
`SYNC_PLAN.md` itself). Hard stop until the user approves or edits the plan. This is
**REVIEW 7** in the playbook.

### 6. Apply (only after approval)
- Write only into `packages/ui/src` (and the flagged `// TODO(human-review)` stubs in
  `packages/core`). Touch nothing in `apps/mobile`, nothing else in `packages/core`,
  nothing in `.figma-src/`.
- Update `packages/ui/src/index.ts` (the barrel) for every add / remove / rename.
- Build the web bundle and run the typecheck. A broken EXPORTED signature in
  `packages/ui` means logic crept back in, or an intentional contract change that
  needs a matching `packages/core` update — surface it to the user, do not paper over
  it by editing core to "make it compile".

### 7. Update the anchor + open the PR
- Set `synced_commit` = `to_commit`, `synced_at` = today, in `FIGMA_SOURCE.json`.
- Create a branch (e.g. `figma-sync/<to_commit-short>`), commit (message references the
  upstream commit range `from..to`), push, and open a PR via `gh`. The PR body embeds
  the `SYNC_PLAN.md` summary and the backend follow-up list. After the PR number is
  known, set `last_sync_pr` and amend.
- Do NOT auto-merge. Do NOT run native builds, signing, or store submission.

## Guardrails
- `.figma-src/` is read-only upstream. Never edit, commit inside, or push to it.
- Write ONLY to `packages/ui` (+ `// TODO(human-review)` stubs in `packages/core`).
  Never wire real auth, secrets, tokens, or data-access during a sync.
- The boundary is the whole point: if a change seems to belong in `packages/core`
  logic or `apps/mobile`, it is a follow-up for a human / `/wire-supabase`, not a
  thing this skill writes.
- Stop at the PR. A human reviews before anything ships (OTA or store).
- This skill is for updates only. First-time bootstrap is `figma-make-to-capacitor`.
