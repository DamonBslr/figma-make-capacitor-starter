---
description: Pull the latest Figma Make design changes into packages/ui (incremental sync, run repeatedly)
argument-hint: [branch] [--to <commit>]
allowed-tools: Bash Read Write Edit Glob Grep
---

Perform an **incremental design sync** using the `figma-sync` skill.

Inputs:
- Branch to sync from: $1 (default `main`)
- `--to <commit>` (optional): sync only up to this upstream commit instead of HEAD —
  the **stepwise** mode for applying Figma Make commits one at a time. Must be after
  the current anchor and at-or-before the branch HEAD.
- The Figma Make repo + last-synced commit come from `FIGMA_SOURCE.json` — set it
  first with `/set-figma-source` if it doesn't exist yet.

**Stepwise (one commit at a time):** list the pending upstream commits, then run
`/sync-figma --to <next-sha>` for each in order — review the plan, approve, let it
open a PR and advance the anchor — before moving to the next. The final commit can be
a plain `/sync-figma` (no `--to`) to catch up to HEAD.

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
