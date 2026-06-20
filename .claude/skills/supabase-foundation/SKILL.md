---
name: supabase-foundation
description: >-
  Step 1 of wiring a Supabase backend into the Capacitor app. Installs
  @supabase/supabase-js, creates a Capacitor-safe Supabase client (session
  persisted via @capacitor/preferences, PKCE flow), sets up env templates, and
  initializes the local supabase/ project. Run ONCE, before schema or stub
  wiring. Trigger on "set up Supabase", "add the Supabase client", or the
  /wire-supabase orchestrator.
allowed-tools: Bash Read Write Edit Glob Grep
---

# Supabase foundation

First step of the backend phase. Sets up the client + project scaffolding only —
no schema, no stub implementations, no auth providers. Those are later skills.

Read `references/capacitor-integration.md` before writing any client code — it
holds the non-obvious rules (storage adapter, PKCE, key safety, edge functions).

## Procedure
1. Run `scripts/install_supabase.sh` (from repo root). It adds
   `@supabase/supabase-js` to `packages/core`, the `supabase` CLI as a root dev
   dependency, runs `supabase init`, and creates `apps/mobile/.env.example`.
2. Copy `assets/client.ts` to `packages/core/src/supabase/client.ts`. Export
   `supabase` from `packages/core/src/index.ts`.
3. Confirm `apps/mobile/.env` is gitignored (it is). Do NOT create a real `.env`
   with values — that is the user's gate (next step).
4. STOP and tell the user the human gate:
   - Create a Supabase project at supabase.com (or `supabase projects create`).
   - Put the Project URL + anon (public) key into `apps/mobile/.env` as
     `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
   - Run `supabase login` and `supabase link --project-ref <ref>` so later steps
     can apply migrations and generate types.

## Hard rules
- The anon key is the ONLY Supabase key that may live in the client. The
  `service_role` key and any third-party API keys NEVER touch the app or git —
  they live in Edge Function secrets only.
- Never write real secret values into files or commit them. Templates only.
- Do not create the Supabase account or project for the user, and do not paste
  keys on their behalf. Surface the steps; they perform them.
