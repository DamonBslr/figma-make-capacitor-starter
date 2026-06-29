#!/usr/bin/env bash
# run-dummy.sh — smoke-test the native shell on a simulator/emulator BEFORE any
# Figma import. Builds the web bundle and launches the placeholder hello-world app.
#
# The generated apps/mobile/ios|android projects are gitignored in the blank starter
# (they carry the throwaway com.example.dummy bundle id). /init-from-figma deletes and
# regenerates them with the real bundle id, then un-ignores them — so nothing here is
# committed and nothing conflicts with the transformation.
#
# Usage:
#   ./scripts/run-dummy.sh ios
#   ./scripts/run-dummy.sh android
#   (or: pnpm dummy:ios / pnpm dummy:android from the repo root)

set -euo pipefail

PLATFORM="${1:-}"
if [[ "$PLATFORM" != "ios" && "$PLATFORM" != "android" ]]; then
  echo "ERROR: specify a platform — usage: run-dummy.sh ios|android" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

cap() { pnpm --filter @app/mobile exec cap "$@"; }

echo "▶ Installing dependencies..."
pnpm install

echo "▶ Building web bundle (apps/mobile → dist)..."
pnpm --filter @app/mobile build

if [[ ! -d "apps/mobile/$PLATFORM" ]]; then
  echo "▶ Adding $PLATFORM native project (dummy com.example.dummy)..."
  cap add "$PLATFORM"
fi

echo "▶ Syncing Capacitor ($PLATFORM)..."
cap sync "$PLATFORM"

echo "▶ Launching dummy app on $PLATFORM..."
cap run "$PLATFORM"
