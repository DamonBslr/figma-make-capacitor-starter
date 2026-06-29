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

echo "▶ Writing real app identity into capacitor.config.ts"
# Replace the VALUES of appId/appName/webDir — works whether the file still holds the
# starter defaults (com.example.dummy / Dummy App / dist) or older {{TOKENS}}.
# perl handles both BSD (macOS) and GNU portably.
perl -i -pe \
  "s/appId:\\s*'[^']*'/appId: '${APP_ID}'/; s/appName:\\s*'[^']*'/appName: '${APP_NAME}'/; s/webDir:\\s*'[^']*'/webDir: '${WEB_DIR}'/" \
  apps/mobile/capacitor.config.ts

echo "▶ Installing Capacitor core + CLI"
add  @capacitor/core
addD @capacitor/cli

echo "▶ Adding iOS + Android platforms"
add @capacitor/ios @capacitor/android
# Drop any throwaway dummy native projects (from `pnpm dummy:*`) so they regenerate with
# the REAL bundle id. They are gitignored in the starter and never committed — safe to rm.
rm -rf apps/mobile/ios apps/mobile/android
cap add ios
cap add android

# Un-ignore the native projects so the real app commits them (standard Capacitor contract).
# Strips only the starter-only "dummy-native" block; the build-artifact ignores stay.
if [ -f .gitignore ]; then
  perl -i -0pe 's/\n?# >>> dummy-native.*?# <<< dummy-native\n//s' .gitignore
fi

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
