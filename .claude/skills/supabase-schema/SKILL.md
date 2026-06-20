---
name: supabase-schema
description: >-
  Step 2 of the Supabase backend. Reads the domain types in
  packages/core/src/types and generates SQL migrations (tables, foreign keys,
  and Row Level Security policies) plus a generated TypeScript DB types file.
  Run after supabase-foundation and after the user has linked a Supabase project.
  Trigger on "generate the database schema", "create the Supabase tables", or the
  /wire-supabase orchestrator.
allowed-tools: Bash Read Write Edit Glob Grep
---

# Supabase schema from domain types

Turns the existing domain types into a real Postgres schema with RLS. The types
are the source of truth — do not invent fields that aren't represented in the app.

Read `references/schema-and-rls.md` first (mapping rules + a worked example).

## Procedure
1. Read every type in `packages/core/src/types`. For each that represents
   persisted data, plan a table. Map the `User` type to a `profiles` table keyed
   to `auth.users(id)` — never add columns to `auth.users`.
2. Write ONE migration at `supabase/migrations/<UTC-timestamp>_init.sql` containing:
   - `create table` per type, with a `user_id uuid references auth.users(id)` owner
     column on every user-owned table (characters, library items, stories, etc.).
   - `alter table ... enable row level security;` on EVERY table.
   - Owner-scoped policies (select/insert/update/delete) checking
     `auth.uid() = user_id`. For `profiles`, check `auth.uid() = id`.
   - A trigger (or documented first-login upsert) to create a `profiles` row on signup.
3. Present the SQL to the user and STOP. Applying it touches a real database:
   the user reviews, then runs `supabase db push` (or pastes into the SQL editor).
   Do NOT push to a remote database automatically.
4. After the user confirms the schema is applied, generate typed DB types:
   `supabase gen types typescript --linked > packages/core/src/types/database.ts`
   and re-export them from the core barrel. Keep the hand-written domain types;
   the generated types are for the data layer to map against.

## Rules
- RLS on for every table, no exceptions. A table without a policy is unreachable
  by design — that's correct; add the policy rather than disabling RLS.
- Don't drop or rewrite existing migrations; add new ones.
- Types drive the schema. If the app needs a field the schema lacks, add it to the
  domain type first, then migrate.
