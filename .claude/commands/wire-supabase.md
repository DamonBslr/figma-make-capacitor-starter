---
description: Wire a Supabase backend into the Capacitor app — spec-driven, with one focused subagent per feature, pausing at each human gate
argument-hint: (no args — walks the steps interactively)
allowed-tools: Task Bash Read Write Edit Glob Grep mcp__claude_ai_Linear__list_issues mcp__claude_ai_Linear__save_issue mcp__claude_ai_Linear__get_issue mcp__claude_ai_Linear__list_issue_statuses mcp__claude_ai_Linear__save_comment
---

Drive the Supabase backend as an ordered, checkpointed process. The backend of a
full prototype is large and unique per app, so this command does NOT use a
hardcoded stub list. Instead it: applies the schema, **specs every backend
feature** (as Linear issues mirrored into `specs/backend/`), pauses for human
review, then implements features **one at a time — each in its own subagent** so
no single context window has to hold the whole backend.

You (this main thread) are the ORCHESTRATOR: you own the human gates, the database
schema/migrations, and the `packages/core` barrel. Subagents own bounded,
single-feature implementation. Run ONE step, STOP at its gate, wait for the user.
Never race ahead through a gate.

## Sequence

1. **Foundation** — invoke the `supabase-foundation` skill.
   GATE: user creates the Supabase project, fills `apps/mobile/.env`, runs
   `supabase login` + `supabase link`. Wait for confirmation.

2. **Schema** — invoke `supabase-schema` to generate migrations + RLS from the
   domain types. Schema is owned HERE, centrally, and applied up front so every
   feature subagent has its tables before any data wiring.
   GATE: user reviews the SQL and applies it (`supabase db push`). Then generate
   `database.ts` types. Wait for confirmation that the schema is live.

3. **Feature discovery & spec** *(spec-driven)* — invoke `supabase-feature-spec`.
   It reads the prototype (`packages/ui`, the `packages/core` stubs,
   `TRANSFORMATION_REPORT.md`), derives the feature list, and writes one Linear
   issue per feature (status **Backlog**) mirrored into `specs/backend/<slug>.md`,
   plus the ordered `specs/backend/_index.md`.
   **SPEC-REVIEW GATE:** STOP. The user reviews/edits/approves the specs (in Linear
   or the mirrored files). Do NOT enter the implementation loop until they approve.

4. **Per-feature implementation** *(one subagent per feature)* — read
   `specs/backend/_index.md` and loop over the approved specs **in sequence order**
   (`data` first, `edge-function` and `native-auth` after their prerequisites).
   For each spec:

   a. **Re-mirror if drifted.** If the user edited the Linear issue after step 3,
      `get_issue` and rewrite `specs/backend/<slug>.md` so the file the subagent
      reads is current. Move the issue to **In Progress** (`save_issue`) and add a
      start comment naming the stubs about to be wired.

   b. **Schema check (orchestrator owns this).** Confirm every table the spec's
      data-model section needs already exists in an applied migration. If a column
      or table is missing, YOU add the migration and surface the schema GATE
      (`supabase db push` + regen `database.ts`) BEFORE dispatching. Subagents
      never write migrations.

   c. **Dispatch ONE subagent** (Task tool, `general-purpose`). Its prompt MUST
      include, explicitly (the subagent starts cold with no memory of discovery):
      - the absolute path to `specs/backend/<slug>.md` (its full instructions);
      - the absolute path to
        `.claude/skills/supabase-foundation/references/capacitor-integration.md`
        (the storage/PKCE/key/edge-fn/interface rules);
      - the Linear issue id (so the summary can be tied back);
      - the spec's stub list;
      - the WRITE-SCOPE invariants: may write `packages/core/**`,
        `supabase/functions/**`, and `apps/mobile` SHELL files (for async-state
        routing) ONLY — NEVER `packages/ui/**`, NEVER `.figma-src/**`, NEVER
        `supabase/migrations/**`;
      - the instruction: invoke the `supabase-wire-stub` skill once per stub,
        sequentially, passing the spec path + stub name each time, preserving every
        exported interface; then return ONE consolidated summary (files changed,
        tables/functions used, any interface change, shell/UI props touched,
        remaining human steps).

   d. **Integrate (orchestrator).** When the subagent returns: update the barrel
      `packages/core/src/index.ts` to export anything new, reconcile shared
      interfaces/types, and run a typecheck. Optionally move the issue to
      **In Review** and post the subagent's summary as a comment.

   e. **Per-feature gate.** Surface the spec's acceptance criteria and the gate for
      its classification:
      - `data`: user runs the app and confirms the capability against real data.
      - `edge-function`: user runs `supabase secrets set <KEY>=...` + deploys the
        function, then tests.
      - `native-auth`: the spec's subagent invoked `supabase-native-auth`; the user
        works the provider-console checklist (`references/human-checklist.md`, with
        `docs/social-auth-setup.md` for step-by-step console instructions) and tests
        on a REAL device — OAuth does not complete in web preview or iOS Simulator.
      On confirmation, move the Linear issue to **Done** with a closing comment.

   f. Proceed to the next spec. One feature at a time — never batch.

## Rules
- Schema ownership stays with this main thread. Subagents consume tables; they
  never author or apply migrations (prevents conflicting migration timestamps).
- One feature per subagent, one feature at a time, in `_index.md` order.
- Never skip the spec-review gate or any per-feature gate. Summarize what changed
  and state the exact gate before pausing.
- Never enter credentials, create accounts, or apply migrations to a remote DB on
  the user's behalf — surface those as gates.
- Every change stays interface-preserving: `packages/ui` and the Figma sync must
  not see a changed signature. sync→async state routes through the `apps/mobile`
  shell as plain props, never `await` logic inside `packages/ui`.
- Auth code is security-critical: the auth/profile feature's subagent must flag in
  its summary that `useAuth` needs human review before shipping.
