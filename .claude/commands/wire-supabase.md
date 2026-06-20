---
description: Wire a Supabase backend into the Capacitor app, step by step, pausing at each human gate
argument-hint: (no args — walks the steps interactively)
allowed-tools: Bash Read Write Edit Glob Grep
---

Drive the Supabase backend wiring as an ordered, checkpointed process. Run ONE
step, then STOP at its human gate and wait for the user before continuing. Never
race ahead through a gate.

## Sequence

1. **Foundation** — invoke the `supabase-foundation` skill.
   GATE: user creates the Supabase project, fills `apps/mobile/.env`, runs
   `supabase login` + `supabase link`. Wait for confirmation.

2. **Schema** — invoke `supabase-schema` to generate migrations + RLS from the
   domain types.
   GATE: user reviews the SQL and applies it (`supabase db push`). Then generate
   `database.ts` types. Wait for confirmation that the schema is live.

3. **Wire data + email/password auth** — invoke `supabase-wire-stub` ONCE PER stub,
   in this order, summarizing after each:
   - `useAuth` (email/password only for now)
   - `useCurrentUser`
   - `useCharacters`
   - `LibraryScreen` data source
   Pause between stubs; let the user run the app and confirm before the next.

4. **AI hooks via Edge Functions** — invoke `supabase-wire-stub` for
   `useStoryGeneration` and `useImageGeneration`. These create Edge Functions
   (keys server-side).
   GATE: user runs `supabase secrets set <PROVIDER_KEY>=...` and deploys the
   functions. Wait, then test.

5. **Native social sign-in** — invoke `supabase-native-auth`.
   GATE: user completes the provider-console + dashboard checklist
   (`references/human-checklist.md`) and tests on a real device.

## Rules
- One step at a time. Summarize what changed and state the exact gate before pausing.
- Never enter credentials, create accounts, or apply migrations to a remote DB on
  the user's behalf — surface those as gates.
- After each code step, suggest the user run the app; treat their confirmation as
  the signal to proceed.
- Keep every change interface-preserving so packages/ui and the Figma sync stay clean.
