#!/usr/bin/env bash
# add_capacitor.sh — install Capacitor, add platforms, install OTA.
# Run from the REPO ROOT. Requires the Figma app's package.json to already
# exist at apps/mobile/package.json (placed there by the skill).
#
#   PM=pnpm ./add_capacitor.sh "Acme" "com.acme.app" "dist"
#
# Args: <AppName> <app.bundle.id> <webDir>
# PM = pnpm | bun | npm   (default pnpm)

set -euo pipefail
PM="${PM:-pnpm}"
APP_NAME="${1:?usage: add_capacitor.sh <AppName> <app.bundle.id> <webDir>}"
APP_ID="${2:?missing app id, e.g. com.acme.app}"
WEB_DIR="${3:-dist}"

if [ ! -f apps/mobile/package.json ]; then
  echo "✗ No apps/mobile/package.json found. Run this from the repo root after the Figma app is in place." >&2
  exit 1
fi

# package-manager-agnostic helpers (run inside apps/mobile)
add()  { case "$PM" in pnpm) pnpm --filter @app/mobile add "$@";; bun) cd apps/mobile && bun add "$@";; *) cd apps/mobile && npm install "$@";; esac; }
addD() { case "$PM" in pnpm) pnpm --filter @app/mobile add -D "$@";; bun) cd apps/mobile && bun add -d "$@";; *) cd apps/mobile && npm install -D "$@";; esac; }
cap()  { case "$PM" in pnpm) pnpm --filter @app/mobile exec cap "$@";; bun) cd apps/mobile && bunx cap "$@";; *) cd apps/mobile && npx cap "$@";; esac; }

echo "▶ Filling capacitor.config.ts template tokens"
# perl handles both BSD (macOS) and GNU sed portably
perl -i -pe \
  "s/\\{\\{APP_NAME\\}\\}/${APP_NAME}/g; s/\\{\\{APP_ID\\}\\}/${APP_ID}/g; s/\\{\\{WEB_DIR\\}\\}/${WEB_DIR}/g" \
  apps/mobile/capacitor.config.ts

echo "▶ Installing Capacitor core + CLI"
add  @capacitor/core
addD @capacitor/cli

echo "▶ Adding iOS + Android platforms"
add @capacitor/ios @capacitor/android
cap add ios
cap add android

echo "▶ Installing OTA live-update plugin (Capgo)"
add @capgo/capacitor-updater

echo "▶ Installing baseline native plugins"
add @capacitor/app @capacitor/status-bar @capacitor/splash-screen @capacitor/preferences

echo "▶ Syncing native projects"
cap sync

cat <<NEXT

✓ Capacitor + OTA installed.

Manual / skill follow-ups (NOT done by this script):
  • Adapt web-only patterns (safe areas, back button, storage → @capacitor/preferences).
  • Create the OTA channel and upload the first bundle via the provider's CLI/dashboard.
  • Native signing + store submission are human-reviewed steps.
NEXT
