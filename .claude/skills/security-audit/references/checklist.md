# Publish-readiness security checklist (Figma → Capacitor → Supabase)

Work through every section. For each item: locate evidence, classify as
✅ compliant / ⚠️ risk / ❌ blocker, record `file:line`. Open the file — never
guess. Categories A–B are the deterministic gate (also enforced by
`scripts/audit-security.sh` and CI); C–G are judgment calls that only a read can
settle. The mapping of "where the rule comes from" is noted so the audit and the
wiring skills can't drift.

Severity convention for this pipeline:
- **Blocker** — ships insecure data/keys to users. Must fix before publish.
- **Risk** — weakens defense-in-depth or will bite later; should fix.

---

## A. `packages/ui` boundary — presentation only

Source of rule: [CLAUDE.md](../../../../CLAUDE.md) "Architecture (non-negotiable
boundary)". `packages/ui` is Figma-synced and may import **types** from
`@app/core` only — never implementations, data, auth, storage, env, or business
logic. Anything found here is a **blocker** (it both leaks logic into the
clobber-on-sync layer and usually bypasses the secure path in `core`).

```bash
# Backend client / data / storage / env access inside the UI layer
git grep -nIE '@supabase/|createClient\(|import\.meta\.env|process\.env|localStorage|sessionStorage' -- 'packages/ui/src/**'
# Raw network calls (UI should take props/callbacks, not fetch)
git grep -nIE '\bfetch\(|axios|XMLHttpRequest' -- 'packages/ui/src/**'
# Auth/session logic that belongs in core
git grep -nIE 'signIn|signOut|getSession|auth\.|jwt|token' -- 'packages/ui/src/**'
```
- `@supabase`, `createClient`, `import.meta.env`/`process.env`, `localStorage` →
  **blocker** (deterministic — the gate fails on these).
- `fetch`/`axios` → blocker unless it's a genuinely presentational asset fetch;
  otherwise the data path must move to a `core` hook and the UI take a prop.
- Auth/session calls → blocker; route through a `core` hook.

## B. Key & secret safety

Source of rule:
[capacitor-integration.md](../../supabase-foundation/references/capacitor-integration.md)
"Key safety". Only the Supabase **anon** key may live in the client — it is
public by design, RLS is the control. `service_role` and all third-party keys
live in Edge Function secrets only.

```bash
# Leaked secrets in tracked source/config (excludes templates & this skill's docs).
# (a) service_role / supabase secret key with a real VALUE — bare mentions of the
#     word (config.toml comments, Deno.env reads) are NOT leaks, only a value is:
git grep -niIE 'service[_-]?role[a-z0-9_]*[^a-z0-9]{0,4}[:=][^a-z0-9]{0,4}eyj|sb_secret_[a-z0-9]{20,}' -- . ':!*.example' ':!.claude/' ':!*.md'
# (b) provider key shapes:
git grep -nIE '(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{20,}|sk_live_[0-9A-Za-z]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----' -- . ':!*.example' ':!.claude/' ':!*.md'
# .env must be ignored, only *.example committed
git ls-files '*.env' '.env' '.env.*' | grep -v '\.example$'   # any output = blocker
git check-ignore apps/mobile/.env && echo ".env ignored ✓"
# Any VITE_-prefixed var that looks like a secret (VITE_ vars are shipped to the client)
git grep -nIE 'VITE_[A-Z_]*(SECRET|SERVICE|PRIVATE|TOKEN|KEY)' -- '*.env*' 'apps/**' 'packages/**'
```
- `service_role` / provider key / private key in a tracked non-example file →
  **blocker** (deterministic).
- A tracked real `.env` → **blocker** (deterministic).
- `VITE_*SECRET` / `VITE_*SERVICE_ROLE` etc. → **blocker**: anything prefixed
  `VITE_` is inlined into the web bundle and is therefore public. The only
  expected client vars are `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
- **Do NOT flag** `VITE_SUPABASE_ANON_KEY` / the anon JWT — public by design.
- `.env.example` must contain placeholders only, no real values.

## C. Supabase client config (`packages/core/src/supabase/client.ts`)

Source of rule:
[capacitor-integration.md](../../supabase-foundation/references/capacitor-integration.md)
"Session persistence", "Auth flow", "Env". Compare against
[the canonical client asset](../../supabase-foundation/assets/client.ts).

```bash
git grep -nIE 'flowType|detectSessionInUrl|persistSession|autoRefreshToken|storage:|localStorage|VITE_SUPABASE_URL' -- 'packages/core/src/**'
```
- `flowType: 'pkce'` present → ✅; missing/`implicit` → **risk** (PKCE is the
  secure native flow).
- `detectSessionInUrl: false` on native → ✅; `true` → **risk** (the deep-link
  callback is handled by the native-auth step, not URL parsing).
- Storage adapter backed by `@capacitor/preferences` → ✅; bare `localStorage`
  or default → **risk** (WKWebView can clear it on backgrounding; sessions drop).
- `persistSession` / `autoRefreshToken` true → ✅.
- `VITE_SUPABASE_URL` must be the bare project URL with **no** `/rest/v1/`
  suffix → otherwise runtime "Invalid path" + a config smell.

## D. RLS & schema (`supabase/migrations/*.sql`)

Source of rule:
[schema-and-rls.md](../../supabase-schema/references/schema-and-rls.md). If there
are **no migrations**, do not mark RLS compliant — say "backend not wired; verify
live via the SQL pack" and move on.

```bash
git grep -nIE 'create table|enable row level security|create policy|using \(|with check \(|security definer|grant ' -- 'supabase/migrations/*.sql'
```
- Every `create table public.<t>` has a matching
  `enable row level security` → ✅; any table without → **blocker** (a table with
  RLS off is fully public; deterministic).
- Every table has explicit policies covering the operations the app performs
  (select/insert/update/delete) → a table with RLS on but **no policy** denies
  all access (functional bug) and a table with RLS off but policies present is
  still wide open — check both.
- Owner policies use `auth.uid() = user_id` (or `= id` for `profiles`) → ✅.
  `using (true)` / `with check (true)` → **blocker** (world-open; deterministic).
- `security definer` functions (e.g. `handle_new_user`) set
  `search_path` (e.g. `set search_path = public`) → otherwise **risk**
  (search-path hijack / privilege escalation). They should do the minimum and
  not be callable to bypass RLS.
- `grant ... to anon` / `to public` on a user-data table → **blocker** unless the
  table is intentionally public reference data.
- Storage buckets created here must have owner-scoped policies (see SQL pack).

## E. Auth implementation (`useAuth` and session handling in `packages/core`)

Source of rule: [PIPELINE_PLAYBOOK.md](../../../../PIPELINE_PLAYBOOK.md) REVIEW 3
("highest-risk code in the app") and
[supabase-wire-stub](../../supabase-wire-stub/SKILL.md) guardrails. Read it line
by line.

```bash
git grep -nIE 'isAuthenticated|useAuth|getSession|getUser|signIn|signOut|TODO\(human-review\)' -- 'packages/core/src/**'
```
- Session/`isAuthenticated` derives from `supabase.auth` (a real session), **not**
  a hardcoded `true`, a faked user object, or a mock → otherwise **blocker**
  (auth theatre — anyone is "logged in").
- Auth & permission errors are surfaced (returned/thrown to UI state), **not**
  swallowed in an empty `catch {}` → swallowed auth errors = **risk** (users and
  reviewers can't tell sign-in failed; can mask security failures).
- No client-side token crafting / manual JWT decode-and-trust / "remember me"
  shortcuts → **blocker** if present.
- No remaining `// TODO(human-review)` on an auth/data path that would ship fake
  behavior → **blocker** (the stub was never wired; the app ships mock data/auth).

## F. Edge functions (`supabase/functions/*`)

Source of rule:
[capacitor-integration.md](../../supabase-foundation/references/capacitor-integration.md)
"Anything that needs a secret → Edge Function". Anything calling a paid/secret
provider must run server-side, not on the device.

```bash
# Provider calls that should NOT be on the device
git grep -nIE 'api\.openai\.com|api\.anthropic\.com|Authorization:\s*Bearer|x-api-key' -- 'packages/**' 'apps/**'
# Function secret handling + gate config
git grep -nIE 'Deno\.env|verify_jwt|Access-Control-Allow-Origin' -- 'supabase/functions/**' 'supabase/config.toml'
```
- A direct provider API call from `packages/core`/`packages/ui`/`apps` → **blocker**
  (the key would have to be on the device). Route via
  `supabase.functions.invoke(...)`.
- Functions read keys from `Deno.env.get(...)`, never hardcoded → hardcoded key =
  **blocker**.
- `verify_jwt = false` for a function that touches user data → **risk/blocker**
  (the function is unauthenticated; confirm it's intentional, e.g. a public
  webhook with its own signature check).
- `Access-Control-Allow-Origin: *` combined with credentialed/authenticated
  calls → **risk**; scope the origin.
- Input from the request is validated before use (no trusting `body` blindly) →
  otherwise **risk**.

## G. Capacitor / OTA shell (`apps/mobile/capacitor.config.ts`, OTA config)

Source of rule: [CLAUDE.md](../../../../CLAUDE.md) shipping model + general
mobile hardening. Native signing, store submission, and iOS encryption-export
compliance are **out of scope here** — defer to
[app-store-readiness-audit](../../app-store-readiness-audit/SKILL.md) and link it.

```bash
git grep -nIE "server:|url:|cleartext|allowNavigation|hostname" -- 'apps/mobile/capacitor.config.ts'
git grep -nIE 'service_role|sk-|secret|Bearer ' -- 'apps/mobile/capacitor.config.ts'
```
- `server.cleartext: true` → **blocker** for a shipped build (allows plaintext
  HTTP); only acceptable for local dev configs.
- `server.url` pointing at a dev host / LAN IP / ngrok in a build that ships →
  **blocker** (the app loads remote code; also breaks offline).
- `allowNavigation` wildcards (`*`) → **risk**; pin to the exact domains needed.
- Any secret embedded in `capacitor.config.ts` or OTA config → **blocker**.
- OTA: the live-update channel/token lives in CI secrets (see
  `.github/workflows/ota-deploy.yml`), never committed.

---

## H. Live-DB verification (always recommend)

Static analysis can't see the live database — RLS may have been toggled in the
dashboard, a bucket made public, or grants changed after the migration ran. Tell
the user to run [verification-queries.sql](verification-queries.sql) in the
Supabase SQL editor (read-only) and report any rows. Each query documents what a
returned row means. This is the "query the app to confirm all data is secure"
step: it proves the live data is actually locked down, not just the committed SQL.
