#!/usr/bin/env bash
# install_supabase.sh — install Supabase client + CLI and scaffold the project.
# Run from the monorepo root. Deterministic setup only.
#   PM=pnpm ./install_supabase.sh     # PM = pnpm | bun | npm (default pnpm)

set -euo pipefail
PM="${PM:-pnpm}"

if [ ! -d packages/core ] || [ ! -d apps/mobile ]; then
  echo "✗ Run from the monorepo root (packages/core and apps/mobile must exist)." >&2
  exit 1
fi

run_in() { # run_in <dir> <add|addD> <pkgs...>
  local dir="$1"; local mode="$2"; shift 2
  ( cd "$dir"
    case "$PM:$mode" in
      pnpm:add)  pnpm add "$@" ;;
      pnpm:addD) pnpm add -D "$@" ;;
      bun:add)   bun add "$@" ;;
      bun:addD)  bun add -d "$@" ;;
      *:add)     npm install "$@" ;;
      *:addD)    npm install -D "$@" ;;
    esac )
}

echo "▶ Adding @supabase/supabase-js to packages/core"
run_in packages/core add @supabase/supabase-js

echo "▶ Adding supabase CLI as a root dev dependency"
case "$PM" in
  pnpm) pnpm add -D -w supabase 2>/dev/null || pnpm add -D supabase ;;
  bun)  bun add -d supabase ;;
  *)    npm install -D supabase ;;
esac

echo "▶ Initializing local supabase/ project"
if [ ! -d supabase ]; then
  case "$PM" in
    pnpm) pnpm exec supabase init ;;
    bun)  bunx supabase init ;;
    *)    npx supabase init ;;
  esac
else
  echo "  supabase/ already exists — skipping init"
fi

echo "▶ Writing apps/mobile/.env.example (template only — no real values)"
cat > apps/mobile/.env.example <<'ENV'
# Supabase — safe to expose in the client (protected by Row Level Security).
# Copy to apps/mobile/.env and fill in from your Supabase project settings.
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
ENV

# Ensure mkdir for the client path so the skill can drop client.ts in.
mkdir -p packages/core/src/supabase

cat <<'NEXT'

✓ Supabase foundation installed.

Human gate (do these, then continue with supabase-schema):
  1. Create a Supabase project (supabase.com or `supabase projects create`).
  2. Copy apps/mobile/.env.example → apps/mobile/.env and fill in URL + anon key.
  3. `supabase login` and `supabase link --project-ref <ref>`.

Do NOT commit apps/mobile/.env. The service_role key never goes in the app.
NEXT
