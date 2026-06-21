# Discovery heuristics: stubs → features → order

How to turn the prototype's stub inventory into a clean, ordered feature list.
The goal is features a human can review and a bounded subagent can implement in
one sitting — not too granular (one issue per stub creates noise) and not too
coarse (one giant "backend" issue defeats the multi-agent split).

## What counts as a feature
A **feature** is one user-facing capability. It usually spans:
- one or more `// TODO(human-review)` stubs in `packages/core`,
- the table(s) it persists to or reads, and
- optionally an edge function (if it calls a secret API).

Cluster by the user-facing capability, not by file. `useAuth` (sign in/up/out)
and `useCurrentUser` (the signed-in profile) are one "Authentication & profile"
feature because they share the `auth.users` + `profiles` surface and a user thinks
of them as one thing. A character list hook plus the screen's data source are one
"library" feature because they read the same table.

Rule of thumb: if two stubs read/write the same table and serve the same screen
flow, they're one feature. If a stub calls an external secret API, it is almost
always its own feature (its gate and risk profile differ).

## Classification (drives the gate)
- **`data`** — implemented directly against the `supabase` client (auth, profile
  reads, CRUD, persistence). Gate: run the app and confirm.
- **`edge-function`** — calls an external paid/secret API (AI story/image
  generation, payments, etc.). The key never touches the device; implement via a
  Supabase Edge Function. Gate: `supabase secrets set ...` + deploy + test.
- **`native-auth`** — native Google/Apple sign-in. Spans provider consoles and
  signing. Gate: the provider-console checklist + real-device test. This feature's
  subagent invokes the `supabase-native-auth` skill.

## Dependency ordering
1. **Authentication & profile is always sequence 1.** Every other table's RLS
   policy checks `auth.uid()`, and `profiles` is keyed to `auth.users(id)`. Nothing
   user-owned can be verified before auth works.
2. **Data features next**, in dependency order — a feature that reads another
   feature's table comes after the feature that owns that table.
3. **Edge-function features after their data prerequisites** (e.g. a generated
   story that gets saved needs the stories table to exist first).
4. **Native-auth last** — it is an enhancement on top of working email/password
   auth (do it only after the auth/profile feature's email/password path works).

## Mapping stubs to tables
- The `User` domain type → a `profiles` table keyed to `auth.users(id)`. Never add
  columns to `auth.users`.
- Every other persisted domain type → its own table with a `user_id uuid
  references auth.users(id)` owner column.
- A stub that returns a domain type but persists nothing (pure computation) is not
  a backend feature — leave it out of the spec list.

## Sanity checks before writing specs
- Every `// TODO(human-review)` stub from the grep maps into exactly one feature
  (no stub orphaned, no stub double-counted).
- Every feature has at least one acceptance criterion that a human can verify by
  running the app.
- The order has no cycle: each `depends_on` points only at lower sequence numbers.
