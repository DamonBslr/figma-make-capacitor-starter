---
name: security-audit
description: >-
  Whole-app, publish-readiness security audit for a Capacitor app built on
  Supabase from a Figma Make prototype. Checks the packages/ui<->core boundary,
  key/secret safety (anon vs service_role, no committed keys, .env ignored),
  Supabase client config (PKCE, native storage), Row Level Security on every
  table, the useAuth implementation, Edge Functions (secrets server-side), and
  Capacitor/OTA shell config. Runs a deterministic gate script, then emits
  read-only SQL to verify the LIVE database, and produces a severity-ranked,
  evidence-backed report (file:line) of blockers and risks. Trigger on "is this
  app safe to publish / ship", "security audit", "audit the app's data security",
  "check RLS / key safety", or "recheck the security findings". For native/store
  submission readiness use app-store-readiness-audit instead; for reviewing a
  single diff use security-review.
allowed-tools: Bash Read Write Edit Glob Grep WebSearch
---

# Security audit (Supabase + Capacitor app)

Produce an evidence-backed answer to "is all the data secure and safe to
publish?" for an app built with this pipeline. Every app here shares one stack —
Figma-derived `packages/ui`, a `packages/core` Supabase client, RLS-protected
Postgres, Edge Functions holding secrets, a Capacitor shell shipping via OTA — so
the audit is specific and repeatable.

This audit is **static code/config + live-DB verification**, not a native/store
review. Defer iOS signing, store guidelines, and encryption-export compliance to
[app-store-readiness-audit](../app-store-readiness-audit/SKILL.md). Unlike the
generic `security-review` (one diff), this audits the whole app for publish.

## Procedure

### 1. Locate sources (degrade gracefully)

Find what exists — a pre-backend app has no migrations or functions yet:

| Concern | Where |
|---|---|
| UI boundary | `packages/ui/src/**` |
| Supabase client | `packages/core/src/supabase/client.ts` |
| Auth / data logic | `packages/core/src/**` |
| Schema + RLS | `supabase/migrations/*.sql` |
| Edge functions | `supabase/functions/**`, `supabase/config.toml` |
| Native shell | `apps/mobile/capacitor.config.ts`, `apps/mobile/index.html` |
| Env / secrets | `.env`, `.env.example`, `apps/mobile/.env*` |

If Supabase isn't wired (no `supabase/` dir, no client), run **A (boundary)** and
**B (key safety)** only and state clearly that backend checks are N/A until it's
wired — don't invent findings for code that doesn't exist.

### 2. Run the deterministic gate first

Run the shared script and capture its output verbatim:

```bash
bash .claude/skills/security-audit/scripts/audit-security.sh
```

This is the same script CI runs, so its PASS/FAIL is authoritative for the
mechanical checks (leaked secrets, `.env` tracked, ui boundary, RLS-off,
world-open policies). Fold each FAIL into the report as a **blocker** with the
file:line the script printed. Then continue to the judgment checks the script
can't make.

### 3. Work the full checklist

Read [references/checklist.md](references/checklist.md) in full and work every
section A–G. For each item: search config + code, **open the file** (don't guess),
classify ✅/⚠️/❌, and record evidence as `file:line`. The checklist carries the
exact grep recipes and ties each rule back to the wiring skill it comes from, so
the audit and the generators can't drift.

The judgment calls the script cannot make (read these yourself):
- **Auth quality** (C, E): is the session real (`supabase.auth`) and not a faked
  `isAuthenticated`? Are auth errors surfaced, not swallowed? Any leftover
  `// TODO(human-review)` shipping fake data/auth?
- **Client config** (C): PKCE, `detectSessionInUrl: false` on native,
  `@capacitor/preferences` storage, URL with no `/rest/v1/` suffix.
- **Edge functions** (F): secret-API calls server-side only, keys from
  `Deno.env`, `verify_jwt`/CORS sane.
- **Capacitor shell** (G): no `cleartext`, no dev `server.url`, no wildcard
  `allowNavigation`, no embedded secret.

### 4. Emit the live-DB verification step

Static analysis cannot see RLS toggled off in the dashboard, a bucket flipped
public, or hand-edited grants. Tell the user to run
[references/verification-queries.sql](references/verification-queries.sql) in the
Supabase SQL editor (read-only) and report rows. In the report, summarize what a
returned row means for each query (e.g. "query 1 rows = tables with RLS off =
publicly readable"). This is the part that proves the **live data** is locked
down, not just the committed SQL. There is no Supabase MCP here — surface the
queries; the user runs them.

### 5. Produce the report

Organize by **severity, not category** — users fix blockers first. Every finding
cites a `file:line` (or "live DB — run query N") and a concrete fix. Never mark
something compliant without evidence from a file or the gate script. Keep
evidence quotes ≤ 3 lines. Structure:

- **Resolved / Compliant** — one line + `file:line` each.
- **Blockers (must fix before publish)** — for each: status, evidence, why it's
  unsafe (what an attacker/leak does), concrete fix.
- **Risks (should fix)** — same shape, "should fix / reviewer-adjacent".
- **Live-DB actions** — run the SQL pack; per query, what a bad result looks like.
- **Out of scope** — one line pointing native/store readiness to
  app-store-readiness-audit.
- **Summary** — blocker count, risk count, compliant count, single next step.

End with a numbered list of 2–4 concrete fixes the agent can apply directly. Do
**not** start fixing until the user picks one.

### 6. Re-audit (when the user says "recheck" / "revalidate")

Re-run the gate script and the full checklist — files may have changed, don't
trust the prior result. For each previously-flagged item, state explicitly
whether it is now resolved or still open, with fresh evidence. Add any new
findings.

## Guardrails

- **Never flag the Supabase anon key** (`VITE_SUPABASE_ANON_KEY` / the anon JWT)
  as a leak — it is public by design; RLS is the control. DO flag `service_role`,
  provider keys, and any other `VITE_*` var that looks secret.
- **Never report a secret as leaked without showing the matching line**, and
  ignore `*.example` templates, placeholders, and this skill's own docs.
- **Never mark RLS compliant from code alone when no migrations exist** — say
  "backend not wired; verify live via the SQL pack."
- **Don't auto-fix.** Report first; offer follow-ups; let the user choose.
- **Don't duplicate native/store/encryption checks** — defer to
  app-store-readiness-audit and link it.
- **Read files; don't guess.** A finding without `file:line` (or a named live
  query) is not a finding.
- The gate script is the single source of truth for mechanical checks — if you
  think it's wrong, fix the script, don't hand-wave a different result in the
  report (the script is what CI enforces).
