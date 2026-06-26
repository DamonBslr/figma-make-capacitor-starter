# Figma Make → Production App — Pipeline Playbook

The repeatable process for turning a Figma Make prototype into a shipped Capacitor
app, AI-driven via Claude Code. Two commands do the heavy lifting; your job is to
review at a handful of points. This doc is the map.

---

## Mental model (what the pipeline assumes)

- **Two repos.** Repo A = the Figma Make repo (Figma owns it, force-mirrors it, you
  never touch it). Repo B = your production monorepo (everything you build).
- **Three layers in Repo B.** `packages/ui` (presentation, Figma-derived — the only
  thing the future Figma sync overwrites), `packages/core` (logic: auth, data, AI),
  `apps/mobile` (Capacitor shell + native projects).
- **Two AI commands.** `/init-from-figma` builds the app; `/wire-supabase` wires the
  backend.
- **Shipping.** UI-only changes go out via OTA (Capgo, minutes). Native changes go
  through the app store.

---

## One-time setup (install once, reuse for every project)

### Skills + commands
Install both kits as **user-level** skills so they're available in every project
without re-installing. From the extracted zips:

```bash
mkdir -p ~/.claude/skills ~/.claude/commands

# Phase 1 — initial transformation
cp -r /path/to/kit/.claude/skills/figma-make-to-capacitor ~/.claude/skills/
cp    /path/to/kit/.claude/commands/init-from-figma.md     ~/.claude/commands/

# Phase 3 — Supabase backend
cp -r /path/to/kit2/.claude/skills/supabase-*              ~/.claude/skills/
cp    /path/to/kit2/.claude/commands/wire-supabase.md      ~/.claude/commands/

# Pre-ship — security audit
cp -r /path/to/kit/.claude/skills/security-audit           ~/.claude/skills/
cp    /path/to/kit/.claude/commands/security-audit.md      ~/.claude/commands/

chmod +x ~/.claude/skills/figma-make-to-capacitor/scripts/*.sh
chmod +x ~/.claude/skills/figma-sync/scripts/*.sh
chmod +x ~/.claude/skills/supabase-foundation/scripts/*.sh
chmod +x ~/.claude/skills/security-audit/scripts/*.sh
```

Verify:
```bash
ls ~/.claude/skills      # figma-make-to-capacitor + 4 supabase-* skills
ls ~/.claude/commands    # init-from-figma + wire-supabase
```

> Team/versioned alternative: commit the same `.claude/` into each repo instead of
> `~/.claude/`. User-level is simplest for solo, fast-moving work.

### Starter repo
Push `figma-to-capacitor-starter/` to GitHub once as a template repo. Every new
project clones it instead of starting from `git init`. This cuts the agent's work
by eliminating the scaffold, CLAUDE.md copy, and OTA wire-up steps.

---

## Per-project process (in order)

### 1. Clone the starter (Repo B)

The `figma-to-capacitor-starter` repo contains the pre-baked monorepo skeleton,
`CLAUDE.md`, `tsconfig.base.json`, the Capacitor config template, and the OTA
shell — everything that is identical for every project.

```bash
git clone https://github.com/your-org/figma-to-capacitor-starter my-app
cd my-app
git remote remove origin        # or: git remote set-url origin <your-new-repo-url>
```

Have the Figma repo URL, an app name, and a bundle id (`com.acme.app`) ready.

**What's already done when you clone the starter:**
- Monorepo structure (`packages/ui`, `packages/core`, `apps/mobile`)
- `tsconfig.base.json` with `@app/ui` / `@app/core` path aliases
- `.gitignore` (excludes `.figma-src/`, native build artifacts, `.env`)
- `CLAUDE.md` at the repo root
- `apps/mobile/capacitor.config.ts` (token template — filled by the agent)
- `apps/mobile/src/App.tsx` with `notifyAppReady` pre-wired
- `.github/workflows/ota-deploy.yml` skeleton

**What the agent still does:** clone `.figma-src/`, inventory the Figma source,
move screens + components, create typed stubs, fill the 3 Capacitor tokens, run
`cap add ios/android`, build, and write `TRANSFORMATION_REPORT.md`.

### 2. Build the app
```
/init-from-figma <figma-repo-url> <AppName> <com.bundle.id>
```
Runs to completion and stops at `TRANSFORMATION_REPORT.md`.
→ **REVIEW 1** (see checklist).

Commit the clean baseline before wiring anything:
```bash
git add -A && git commit -m "Initial transformation from Figma Make"
```

### 3. Wire the backend
```
/wire-supabase
```
It walks every step itself — creating the Supabase project, pasting credentials into
`.env`, generating the schema, then **specing every backend feature** (one Linear
issue per feature, mirrored into `specs/backend/`) and implementing them **one at a
time, each in its own subagent** — through AI hooks and native auth, pausing at each
gate. You don't need to pre-create anything. The feature list is derived from your
actual prototype, not a fixed list.
→ **REVIEW 2–6** happen along the way (see checklist), including the new
spec-review gate.

### 4. Ship
- OTA: set up the Capgo channel and push the first bundle (the transformation report
  lists the exact command).
- Native: configure iOS provisioning + Android keystore, then submit to the stores.

---

## What to review as a human (the only parts that need your eyes)

Everything else is automated. These are the checkpoints worth stopping for.

**REVIEW 1 — after `/init-from-figma`, read `TRANSFORMATION_REPORT.md`**
- Skim what moved into `packages/ui` vs `packages/core`. No data/auth/business logic
  should be sitting in `packages/ui` — if it is, that's a bug, flag it.
- Glance at the stub list so you know what's fake before you start wiring.

**REVIEW 2 — schema SQL, before it's applied**
- Paste it for a second opinion before `db push`. Checking: RLS enabled on *every*
  table, owner policies use `auth.uid()`, no table left world-readable.

**REVIEW 2.5 — the feature specs, before any wiring (NEW spec-review gate)**
- `/wire-supabase` writes one spec per backend feature (a Linear issue under the
  "<App> Backend" project, mirrored into `specs/backend/<slug>.md`) and stops.
- Read the feature list + `specs/backend/_index.md` ordering. Confirm every fake
  stub maps to a feature, the order is sane (auth first), and each spec's interface
  contract + acceptance criteria look right. Edit in Linear or the mirrored files,
  then approve. Implementation does not start until you do.

**REVIEW 3 — the `useAuth` implementation (highest-risk code in the app)**
- Read it line by line. Session comes from Supabase (not a faked `isAuthenticated`),
  errors are surfaced not swallowed, no token shortcuts.

**REVIEW 4 — key safety (do this once backend is wired)**
```bash
git grep -nE "service_role|sk-|secret" -- . ':!*.example' || echo "clean"
git check-ignore apps/mobile/.env && echo ".env is ignored ✓"
```
Only the Supabase **anon** key may appear in the client. Provider/AI keys live in
Edge Function secrets, never in the repo. These two snippets are exactly what
`/security-audit` automates (plus RLS, boundary, and live-DB checks) — run the
command instead of grepping by hand once the backend is wired.

**REVIEW 5 — async interface changes (e.g. image generation)**
- When a sync stub became async, confirm the UI stayed prop-driven (loading state
  passed as a prop, no `await` logic added inside `packages/ui`). That's what keeps
  the Figma sync non-destructive.

**REVIEW 6 — native OAuth**
- Work the console checklist, then test Google/Apple sign-in on a **real device**
  (OAuth doesn't complete reliably in web preview). Confirm the session survives an
  app restart.

**REVIEW 7 — the sync plan, before any file changes (ongoing, after launch)**
- `/sync-figma` writes `SYNC_PLAN.md` and stops. Read the per-file table: confirm
  every change is classified sanely (ui-only vs ui+stub vs backend-follow-up), the
  boundary check holds (nothing written outside `packages/ui` except flagged stubs),
  and no exported `packages/ui` signature is silently changed. Edit the plan or
  approve. Then the sync applies + opens a PR — review that PR before merge, and run
  `/wire-supabase` for any backend follow-ups it flagged.

**Before you ship — run `/security-audit`**
- One command runs the whole pre-ship gate: RLS on every table · `useAuth` real ·
  no leaked keys · `.env` gitignored · `packages/ui` boundary clean · edge-function
  secrets server-side. It also emits read-only SQL to confirm the **live** database
  matches the code. Clear every blocker before OTA/store ship.
- Still confirm the human-only bits by hand: OTA channel live · native signing
  configured · (for the store) run `/app-store-readiness-audit`.

---

## Realistic session pacing
- Session A: steps 1–2 + REVIEW 1. (App boots with stubs.)
- Session B: `/wire-supabase` through schema + feature specs + the first data features
  (one subagent each) + REVIEW 2–4. (Real auth + data.)
- Session C: AI hooks (Edge Functions) + native OAuth + REVIEW 5–6.
Each gate is a clean stopping point; don't force it all into one sitting.

---

## Ongoing Figma sync (after launch)
When the design evolves in Figma Make, pull the changes in with one command:

```
/sync-figma [branch]        # default branch: main
```

It runs the `figma-sync` skill, which:
1. Reads `FIGMA_SOURCE.json` — the committed anchor recording which upstream Figma
   commit the app currently reflects. (First run establishes the anchor and stops;
   real diffs start from the next run.)
2. Fetches `.figma-src/` (read-only) and diffs `synced_commit..origin/<branch>`.
3. Maps each changed file to a layer and writes `SYNC_PLAN.md` — a per-file table
   (ui-only / ui+stub / backend-follow-up / delete / ignore) with a boundary check.
   → **REVIEW 7** (see checklist). **Hard stop — nothing is written yet.**
4. After you approve: applies UI-only changes into `packages/ui` (plus
   `// TODO(human-review)` stubs for anything implying backend work), typechecks,
   advances `FIGMA_SOURCE.json`, and opens a PR. Backend work is flagged for
   `/wire-supabase`, never wired by the sync.

This is non-destructive by construction: it writes only `packages/ui` (+ flagged
stubs), so your hand-written `packages/core` logic survives every sync. UI-only
syncs ship via OTA once the PR merges; anything touching `packages/core` goes
through `/wire-supabase` first.

---

## Quick reference

| When | Command | Stops at | You review |
|------|---------|----------|------------|
| New app from prototype | clone starter → `/init-from-figma <url> <name> <id>` | `TRANSFORMATION_REPORT.md` | what moved, stub list |
| Wire backend | `/wire-supabase` | each gate (self-guided) | schema/RLS, `useAuth`, keys, async UI, OAuth |
| Sync a design change | `/sync-figma [branch]` | `SYNC_PLAN.md`, then a PR | per-file mapping, boundary check |
| Security audit before ship | `/security-audit` | severity-ranked report | blockers/risks, then live-DB SQL |
| Ship UI change | OTA push (Capgo) | — | — |
| Ship native change | store submission | — | — |
