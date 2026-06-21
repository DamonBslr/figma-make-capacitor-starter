---
description: Pull the latest Figma Make design changes into packages/ui (incremental sync, run repeatedly)
argument-hint: [branch]
allowed-tools: Bash Read Write Edit Glob Grep
---

Perform an **incremental design sync** using the `figma-sync` skill.

Inputs:
- Branch to sync from: $1 (default `main`)
- The Figma Make repo + last-synced commit come from `FIGMA_SOURCE.json` (the skill
  establishes this anchor on the first run).

Rules:
- Follow the skill's procedure in order; read its `references/mapping-heuristics.md`
  and `references/sync-plan-template.md` before mapping.
- `.figma-src/` is read-only upstream — never edit, commit inside, or push to it.
- Write ONLY to `packages/ui` (plus `// TODO(human-review)` stubs in `packages/core`).
  Never wire real auth, secrets, or data-access; never touch `apps/mobile` or other
  `packages/core` logic.
- Stop at the **sync-review gate** (`SYNC_PLAN.md`) before changing any file, and stop
  again at the PR. Do not auto-merge, run native builds, or submit to stores.
- This command is for updates only. First-time bootstrap is `/init-from-figma`.
