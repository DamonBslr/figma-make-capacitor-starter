#!/usr/bin/env bash
#
# audit-security.sh — deterministic, false-positive-averse security gate for the
# Figma -> Capacitor -> Supabase pipeline. The SINGLE SOURCE OF TRUTH for the
# mechanical checks: the /security-audit skill runs this and folds the result
# into its report, and .github/workflows/security-audit.yml runs the exact same
# script so the skill and CI can never drift.
#
# Scope: only checks that are unambiguous enough to BLOCK a merge. Judgment-based
# checks (auth quality, edge-function review, live-DB drift) live in the skill's
# references/checklist.md, not here.
#
# Exit 0 = all gates pass. Exit 1 = at least one gate failed. Exit 2 = misuse.
#
# Usage: bash .claude/skills/security-audit/scripts/audit-security.sh
# Run from anywhere inside the repo; it cd's to the git toplevel itself.

set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "FATAL: not inside a git repository" >&2
  exit 2
}
cd "$ROOT"

FAIL=0
note()  { printf '   %s\n' "$1"; }
pass()  { printf '\033[32mPASS\033[0m  %s\n' "$1"; }
skip()  { printf '\033[33mSKIP\033[0m  %s\n' "$1"; }
fail()  { printf '\033[31mFAIL\033[0m  %s\n' "$1"; FAIL=1; }

echo "Security gate — $(basename "$ROOT")"
echo "-------------------------------------------"

# ---------------------------------------------------------------------------
# 1. Leaked secrets in tracked files.
#    Only the Supabase ANON key may live in the client; service_role keys,
#    provider keys, and private keys must never be committed. We scan tracked
#    source/config only and deliberately exclude this skill's own docs
#    (which contain these patterns as examples), *.example templates, lockfiles,
#    and markdown (intentionally documents the patterns).
# ---------------------------------------------------------------------------
SECRET_PATHSPEC=(-- . ':!*.example' ':!.claude/' ':!*.md' ':!pnpm-lock.yaml' ':!*.lock')
# (a) A Supabase service_role / secret key with an actual VALUE (case-insensitive).
#     Requires a JWT (eyJ...) or sb_secret_ token next to the name, so a bare
#     mention of the word "service_role" — the default supabase/config.toml
#     comment, or a legit Deno.env.get("...SERVICE_ROLE_KEY") read — is NOT
#     flagged. Only a committed value is.
SR_RE='service[_-]?role[a-z0-9_]*[^a-z0-9]{0,4}[:=][^a-z0-9]{0,4}eyj[a-z0-9_.-]{10,}'
SR_RE="$SR_RE|sb_secret_[a-z0-9]{20,}"               # new Supabase secret key format
# (b) Provider key shapes — case-sensitive (the shapes are case-specific). Min
#     lengths keep placeholders like "sk-xxx" out.
PK_RE='(^|[^A-Za-z0-9])sk-[A-Za-z0-9]{20,}'          # OpenAI / Anthropic style
PK_RE="$PK_RE|sk_live_[0-9A-Za-z]{20,}"              # Stripe live
PK_RE="$PK_RE|AKIA[0-9A-Z]{16}"                      # AWS access key id
PK_RE="$PK_RE|AIza[0-9A-Za-z_-]{35}"                 # Google API key
PK_RE="$PK_RE|-----BEGIN [A-Z ]*PRIVATE KEY-----"    # PEM private key

secret_hits="$( { git grep -niIE "$SR_RE" "${SECRET_PATHSPEC[@]}"; \
                  git grep -nIE  "$PK_RE" "${SECRET_PATHSPEC[@]}"; } 2>/dev/null | sort -u || true)"
if [ -n "$secret_hits" ]; then
  fail "Possible secret committed to a tracked file:"
  printf '%s\n' "$secret_hits" | sed 's/^/     /'
  note "Move service_role/provider keys to Edge Function secrets (supabase secrets set); never commit them."
else
  pass "No leaked secrets in tracked source/config."
fi

# ---------------------------------------------------------------------------
# 2. .env must be gitignored and not tracked. Only *.example is committed.
# ---------------------------------------------------------------------------
tracked_env="$(git ls-files '*.env' '.env' '.env.*' 2>/dev/null | grep -v '\.example$' || true)"
if [ -n "$tracked_env" ]; then
  fail ".env file(s) are tracked by git (must be ignored):"
  printf '%s\n' "$tracked_env" | sed 's/^/     /'
else
  pass "No real .env files tracked (only *.example, if any)."
fi

# ---------------------------------------------------------------------------
# 3. packages/ui boundary — presentation only. No backend client, env access,
#    or device storage may appear there (CLAUDE.md non-negotiable boundary).
# ---------------------------------------------------------------------------
if [ -d packages/ui/src ]; then
  BOUNDARY_RE='@supabase/|createClient\(|import\.meta\.env|process\.env|localStorage|sessionStorage'
  boundary_hits="$(git grep -nIE "$BOUNDARY_RE" -- 'packages/ui/src/**' 2>/dev/null || true)"
  if [ -n "$boundary_hits" ]; then
    fail "Backend/data/storage access found inside packages/ui (must move to packages/core):"
    printf '%s\n' "$boundary_hits" | sed 's/^/     /'
  else
    pass "packages/ui is free of backend client, env, and storage access."
  fi
else
  skip "packages/ui/src not found — boundary check not applicable."
fi

# ---------------------------------------------------------------------------
# 4. RLS — every table created in supabase/migrations must enable row level
#    security. A table with RLS off is a public table.
# ---------------------------------------------------------------------------
mig_files="$(git ls-files 'supabase/migrations/*.sql' 2>/dev/null || true)"
if [ -n "$mig_files" ]; then
  # Lowercase the whole migration corpus once (SQL keywords are case-insensitive).
  sql="$(cat $mig_files | tr '[:upper:]' '[:lower:]')"
  enable_lines="$(printf '%s\n' "$sql" | grep -E 'enable row level security' || true)"
  tables="$(printf '%s\n' "$sql" \
    | grep -oE 'create table (if not exists )?(public\.)?[a-z0-9_]+' \
    | sed -E 's/create table (if not exists )?//; s/public\.//' \
    | sort -u)"
  missing=""
  for t in $tables; do
    if ! printf '%s\n' "$enable_lines" | grep -qE "table (public\.)?$t([^a-z0-9_]|$)"; then
      missing="$missing $t"
    fi
  done
  if [ -n "${missing// /}" ]; then
    fail "Table(s) created without 'enable row level security':$missing"
    note "Add: alter table public.<t> enable row level security;  plus owner policies."
  elif [ -z "$tables" ]; then
    skip "Migrations present but no 'create table' statements found."
  else
    pass "RLS enabled on every table in supabase/migrations."
  fi

  # 5. World-open policies (using/with check (true)) — defeats RLS entirely.
  open_hits="$(git grep -nIE 'using[[:space:]]*\([[:space:]]*true[[:space:]]*\)|with[[:space:]]+check[[:space:]]*\([[:space:]]*true[[:space:]]*\)' -- 'supabase/migrations/*.sql' 2>/dev/null || true)"
  if [ -n "$open_hits" ]; then
    fail "World-open RLS policy (using/with check (true)) — every row exposed:"
    printf '%s\n' "$open_hits" | sed 's/^/     /'
    note "Scope to the owner: using (auth.uid() = user_id)."
  else
    pass "No world-open (true) RLS policies."
  fi
else
  skip "supabase/migrations not found — backend not wired yet; RLS gates skipped."
fi

echo "-------------------------------------------"
if [ "$FAIL" -eq 0 ]; then
  echo "Security gate: PASS"
else
  echo "Security gate: FAIL — fix the items above before publishing."
fi
exit "$FAIL"
