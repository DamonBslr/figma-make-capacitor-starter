#!/usr/bin/env bash
# scaffold_monorepo.sh — create the production monorepo skeleton.
# Deterministic setup only; the UI placement and logic split are done by the skill.
# Run from the directory that should become the monorepo root.
#
#   PM=pnpm ./scaffold_monorepo.sh <app-name>   # e.g. scaffold_monorepo.sh acme
#   PM=pnpm ./scaffold_monorepo.sh              # falls back to "app-monorepo"

set -euo pipefail
PM="${PM:-pnpm}"

# Derive a kebab-case monorepo name from the first arg (or fall back to placeholder).
RAW_NAME="${1:-}"
if [ -n "${RAW_NAME}" ]; then
  MONOREPO_NAME="$(echo "${RAW_NAME}" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
else
  MONOREPO_NAME="app-monorepo"
fi

echo "▶ Scaffolding monorepo '${MONOREPO_NAME}' (package manager: ${PM})"

mkdir -p apps/mobile packages/ui/src packages/core/src .github/workflows

# ---- root package.json (workspaces field works for npm/bun; pnpm uses the yaml) ----
cat > package.json <<JSON
{
  "name": "${MONOREPO_NAME}",
  "version": "0.0.0",
  "private": true,
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "dev": "pnpm --filter @app/mobile dev",
    "build:ui": "echo 'build packages/ui' ",
    "build:mobile": "echo 'build apps/mobile' ",
    "sync": "echo 'run cap sync from apps/mobile' "
  }
}
JSON

# ---- pnpm workspace file (ignored by other PMs) ----
if [ "${PM}" = "pnpm" ]; then
  cat > pnpm-workspace.yaml <<'YAML'
packages:
  - "apps/*"
  - "packages/*"
YAML
fi

# ---- base TS config with path aliases for the two layers ----
cat > tsconfig.base.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "jsx": "react-jsx",
    "strict": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "baseUrl": ".",
    "paths": {
      "@app/ui": ["packages/ui/src"],
      "@app/ui/*": ["packages/ui/src/*"],
      "@app/core": ["packages/core/src"],
      "@app/core/*": ["packages/core/src/*"]
    }
  }
}
JSON

# ---- presentation layer package (Figma-derived; dumb) ----
cat > packages/ui/package.json <<'JSON'
{
  "name": "@app/ui",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "src/index.ts",
  "peerDependencies": { "react": ">=18", "react-dom": ">=18" }
}
JSON
[ -f packages/ui/src/index.ts ] || echo "// presentation layer barrel — exports Figma-derived screens/components" > packages/ui/src/index.ts

# ---- logic layer package (hand-written; never touched by Figma sync) ----
cat > packages/core/package.json <<'JSON'
{
  "name": "@app/core",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "src/index.ts"
}
JSON
[ -f packages/core/src/index.ts ] || echo "// logic layer barrel — auth, data, api, domain types, hooks" > packages/core/src/index.ts

# ---- gitignore: keep .figma-src and build output out; native projects ARE committed ----
cat > .gitignore <<'GI'
node_modules/
dist/
build/
.figma-src/
*.log
.env
.env.*
.DS_Store
apps/mobile/ios/App/build/
apps/mobile/ios/App/Pods/
apps/mobile/android/.gradle/
apps/mobile/android/app/build/
apps/mobile/android/build/
ios/DerivedData/
GI

echo "✓ Monorepo skeleton ready."
echo "  Next (skill-driven): move Figma UI into packages/ui & apps/mobile, then split logic into packages/core."
