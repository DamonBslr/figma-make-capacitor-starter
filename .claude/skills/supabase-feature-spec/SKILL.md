---
name: supabase-feature-spec
description: >-
  Step 2.5 of the Supabase backend. Discovers the prototype's backend-needing
  features by reading packages/ui screens, the packages/core stubs, and
  TRANSFORMATION_REPORT.md, then authors one spec per feature: a Linear issue
  (source of truth) mirrored into specs/backend/<feature>.md. Stops at the
  spec-review gate before any implementation. Replaces the old hardcoded stub
  list. Trigger on "spec the backend features", "discover backend work", or the
  /wire-supabase orchestrator.
allowed-tools: Bash Read Write Edit Glob Grep mcp__claude_ai_Linear__list_issues mcp__claude_ai_Linear__save_issue mcp__claude_ai_Linear__get_issue mcp__claude_ai_Linear__list_issue_statuses mcp__claude_ai_Linear__list_projects mcp__claude_ai_Linear__save_project mcp__claude_ai_Linear__list_issue_labels mcp__claude_ai_Linear__create_issue_label mcp__claude_ai_Linear__save_comment
---

# Discover backend features → spec them

The app prototype is large and unique per project, so the backend can't be a
hardcoded stub list. This skill READS the prototype, derives the real feature
list, and writes a reviewable spec per feature (GitHub spec-kit style). It does
NOT implement anything — implementation is the orchestrator's per-feature loop,
which runs only after the human approves these specs.

Run this AFTER `supabase-foundation` and `supabase-schema`, and BEFORE any stub
wiring. Read `references/discovery-heuristics.md` (clustering + ordering rules)
and `references/spec-template.md` (the exact spec shape) before authoring.

## Inputs
- Linear team: `Damon Basler` (id `75af36df-c177-4306-8369-267fe923959a`).
- App name (for the Linear project + label). Read it from `capacitor.config.ts`
  or the root `package.json` if not given.

## Procedure

### 1. Discover the features
- Read `TRANSFORMATION_REPORT.md` — its stub list is the authoritative inventory
  of `// TODO(human-review)` touchpoints the transformation produced.
- `grep -rn "TODO(human-review)" packages/core/src` to confirm/augment that list
  against live code (the report can drift).
- Read the `packages/ui/src` screens and `packages/core/src/types` to map each
  stub → the UI surface that consumes it → the domain type it returns.
- Cluster the stubs into **features** per `references/discovery-heuristics.md`
  (a feature = one user-facing capability, spanning one+ stubs plus the table(s)
  or edge function it needs).
- **Classify** each feature: `data` | `edge-function` (external secret API) |
  `native-auth`. This classification tells the orchestrator which gate applies.
- Decide the dependency order (auth/profile is always sequence 1 — every RLS
  policy depends on `auth.uid()`; edge-function and native-auth features come
  after their data prerequisites).

### 2. Set up Linear (idempotent)
- `list_projects` for the team; if no project named `<App> Backend`, create it
  with `save_project`. Capture its id.
- `list_issue_labels`; if no `backend-spec` label, `create_issue_label`. Tolerate
  "already exists" on re-runs — check first, create only if missing.
- `list_issue_statuses` for the team and resolve the ids for **Backlog**,
  **In Progress**, **In Review**, **Done** (names may vary — match by closest
  workflow state). Record them in `specs/backend/_index.md` so the orchestrator
  reuses the same ids.

### 3. Author one spec per feature (sequential)
For each feature, in dependency order:
- Fill every section of `references/spec-template.md`. Copy each touched stub's
  EXPORTED interface signature verbatim — that signature is the contract the
  implementation must preserve.
- **Linear (source of truth):** `save_issue` — title `[backend] <Feature>`,
  project = `<App> Backend`, label = `backend-spec`, status = **Backlog**,
  description = the full spec markdown (with a leading metadata line: sequence #,
  classification, depends_on). Capture the returned issue identifier + url.
  - Idempotency: if `specs/backend/<slug>.md` already exists and names a
    `linear_issue`, UPDATE that issue (pass its id to `save_issue`) instead of
    creating a duplicate.
- **Mirror to repo:** write `specs/backend/<feature-slug>.md` with the identical
  spec body, preceded by a YAML front-block:
  ```yaml
  ---
  feature_slug: <slug>
  linear_issue: <DAM-123>
  linear_url: <url>
  classification: data | edge-function | native-auth
  sequence: <n>
  depends_on: [<slug>, ...]
  stubs: [packages/core/src/...]
  tables: [<table>, ...]
  edge_functions: [<name>, ...]
  ---
  ```
  The mirror is what cold-start subagents and the PR read — keep it identical to
  the Linear description.

### 4. Write the ordering manifest
Write `specs/backend/_index.md`: an ordered table — `seq | feature | slug |
classification | linear_issue | depends_on` — plus the resolved Linear status ids
(Backlog/In Progress/In Review/Done). This is the list the orchestrator loops
over and the single place status ids live.

### 5. STOP at the spec-review gate
Present the feature list + ordering to the user. Tell them to review and edit the
specs — in Linear or the mirrored `specs/backend/*.md` files — and approve before
any implementation begins. **Hard stop. Do not wire any stub.** Note that if they
edit a Linear issue after this, the orchestrator re-mirrors before dispatching so
the repo file stays the source the subagent reads.

## Rules
- Read-only against the prototype: never edit `packages/ui`, `.figma-src`, or any
  stub here. This skill only writes `specs/backend/**` and Linear.
- The types/stubs drive the spec — never invent a feature, field, or table that no
  stub or domain type represents.
- One issue per feature; keep slugs stable so re-runs update rather than duplicate.
- This skill does not spawn subagents and does not implement. It stops at the gate.
