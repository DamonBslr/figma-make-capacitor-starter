---
description: Whole-app publish-readiness security audit (RLS, key safety, ui/core boundary, auth, edge functions) for the Supabase + Capacitor app
argument-hint: (no args — audits the whole app) | recheck
allowed-tools: Bash Read Write Edit Glob Grep WebSearch
---

Run a **publish-readiness security audit** of this app using the `security-audit`
skill: "is all the data secure and safe to publish?"

Inputs:
- `recheck` (optional): re-validate a previous audit — re-run everything and state,
  per prior finding, whether it is now resolved or still open.

Procedure:
- Follow the skill's procedure in order. **Run the gate script first**
  (`bash .claude/skills/security-audit/scripts/audit-security.sh`) — it is the same
  script CI enforces — then read `references/checklist.md` in full and work the
  judgment checks it can't make.
- Emit `references/verification-queries.sql` for the user to run in the Supabase
  SQL editor (read-only) to verify the LIVE database, not just committed SQL.
- Produce the report ranked by severity (Blockers → Risks), every finding citing
  `file:line` or a named live query, ending with 2–4 concrete fixes.

Rules:
- Never flag the Supabase **anon** key as a leak (public by design). DO flag
  `service_role`, provider keys, and secret-looking `VITE_*` vars.
- Read files; no finding without `file:line` (or a named live query). Evidence
  quotes ≤ 3 lines.
- **Do not auto-fix** — report first, let the user pick a follow-up.
- Native signing / store submission / iOS encryption-export compliance are out of
  scope here — point those to `/app-store-readiness-audit` (the
  `app-store-readiness-audit` skill); for a single-diff review use `security-review`.
