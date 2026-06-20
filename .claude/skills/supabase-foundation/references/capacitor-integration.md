# Supabase + Capacitor: integration rules

The non-obvious rules every Supabase step in this repo must follow. When in
doubt, prefer the safe/native option below over the plain web default.

## Session persistence
The supabase-js client defaults to `localStorage`, which WKWebView can clear when
the app is backgrounded. Always pass a `@capacitor/preferences`-backed storage
adapter to `auth.storage` so sessions survive restarts and backgrounding. The
adapter is async; supabase-js supports async storage.

## Auth flow
Use `flowType: 'pkce'` — it is the recommended, most secure flow and the only one
that behaves correctly for native OAuth. Set `detectSessionInUrl: false` on native;
the deep-link callback is handled explicitly by the native-auth step, not by URL
parsing. Keep `persistSession: true` and `autoRefreshToken: true`.

## Key safety (non-negotiable)
- `anon` (public) key → may live in the client. It is meant to be public; RLS is
  what protects data, not key secrecy.
- `service_role` key → server only. NEVER in the app, NEVER in git.
- Third-party API keys (AI providers, etc.) → Edge Function secrets only
  (`supabase secrets set`). NEVER in the client.

## Anything that needs a secret → Edge Function
If a hook calls an external paid/secret API (story generation, image generation),
it must NOT call that API from the device. Implement a Supabase Edge Function that
holds the key server-side, and have the core hook call
`supabase.functions.invoke('<fn>', ...)`. This keeps keys off the device and lets
you rotate them without an app release.

## Row Level Security (always on)
Every table created gets `enable row level security` plus explicit policies.
A table with RLS off is a public table. Owner-scoped pattern: a `user_id uuid`
column referencing `auth.users(id)`, with policies checking `auth.uid() = user_id`.

## The User type → a `profiles` table
You cannot write app columns onto `auth.users`. Map the `User` domain type to a
`profiles` table keyed by `id uuid references auth.users(id)`, populated on signup
(via trigger or first-login upsert).

## Env (Vite)
Vite reads `apps/mobile/.env`. Client env vars must be prefixed `VITE_`
(`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`) and accessed via `import.meta.env`.
`.env.example` is committed; `.env` is gitignored.

## Interface preservation (why this whole thing stays Figma-safe)
Wiring a stub must NOT change the exported interface that `packages/ui` and
`apps/mobile` already consume. Same hook name, same shape. If a real implementation
must become async where the stub was sync, do NOT push `await` logic into
`packages/ui` — route the async state (loading flags, results) through the shell in
`apps/mobile` and pass plain props/callbacks down, exactly like `StoryScreen`
already receives `isGenerating`. The UI stays dumb; the Figma sync stays clean.
