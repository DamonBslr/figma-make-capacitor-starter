#!/usr/bin/env bash
# iOS build and submit pipeline.
#
# Commands:
#   build    — web bundle → cap sync → xcodebuild archive → export .ipa
#   submit   — upload the exported .ipa to App Store Connect
#   deploy   — build + submit (default)
#
# Usage:
#   ./scripts/deploy-ios.sh [build|submit|deploy] [apple-id] [app-specific-password]
#
# Credentials can also be set via env:
#   APPLE_ID, APP_SPECIFIC_PASSWORD
#
# App-specific password: appleid.apple.com → Sign-In and Security → App-Specific Passwords

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Load .env from repo root if present
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -o allexport
  # shellcheck source=/dev/null
  source "$REPO_ROOT/.env"
  set +o allexport
fi

COMMAND="${1:-deploy}"
APPLE_ID="${2:-${APPLE_ID:-}}"
APP_PASSWORD="${3:-${APP_SPECIFIC_PASSWORD:-}}"

MOBILE_DIR="$REPO_ROOT/apps/mobile"
IOS_WORKSPACE="$MOBILE_DIR/ios/App/App.xcworkspace"
SCHEME="App"
CONFIGURATION="Release"
BUILD_DIR="$REPO_ROOT/.build/ios"
ARCHIVE_PATH="$BUILD_DIR/App.xcarchive"
IPA_DIR="$BUILD_DIR/ipa"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"

# ── Helpers ───────────────────────────────────────────────────────────────────

require_credentials() {
  if [[ -z "$APPLE_ID" || -z "$APP_PASSWORD" ]]; then
    echo "ERROR: Apple ID and app-specific password are required for submit."
    echo "  Usage: pnpm submit:ios <apple-id> <app-specific-password>"
    echo "  Or set APPLE_ID and APP_SPECIFIC_PASSWORD environment variables."
    echo "  Generate app-specific password at: appleid.apple.com → App-Specific Passwords"
    exit 1
  fi
}

require_xcode() {
  if ! command -v xcodebuild &>/dev/null; then
    echo "ERROR: xcodebuild not found. Install Xcode and command-line tools."
    exit 1
  fi
}

# ── Build ─────────────────────────────────────────────────────────────────────

run_build() {
  require_xcode

  echo "▶ Building web bundle..."
  cd "$MOBILE_DIR"
  pnpm build

  echo "▶ Syncing Capacitor..."
  pnpm exec cap sync ios

  echo "▶ Archiving (this takes a few minutes)..."
  mkdir -p "$BUILD_DIR"

  xcodebuild archive \
    -workspace "$IOS_WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM=9B4Y38J5SL

  echo "▶ Exporting IPA..."
  cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>export</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>9B4Y38J5SL</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$IPA_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -allowProvisioningUpdates

  IPA_PATH=$(find "$IPA_DIR" -name "*.ipa" | head -1)
  if [[ -z "$IPA_PATH" ]]; then
    echo "ERROR: IPA not found after export. Check Xcode signing setup."
    exit 1
  fi

  echo "✓ Build complete: $IPA_PATH"
}

# ── Submit ────────────────────────────────────────────────────────────────────

run_submit() {
  require_credentials

  IPA_PATH=$(find "$IPA_DIR" -name "*.ipa" 2>/dev/null | head -1)
  if [[ -z "$IPA_PATH" ]]; then
    echo "ERROR: No IPA found at $IPA_DIR. Run 'pnpm build:ios' first."
    exit 1
  fi

  echo "▶ Uploading $IPA_PATH to App Store Connect..."
  xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --username "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --verbose

  echo ""
  echo "✓ Submit complete. Build will appear in App Store Connect in ~15 min."
  echo "  https://appstoreconnect.apple.com"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────

case "$COMMAND" in
  build)
    run_build
    ;;
  submit)
    run_submit
    ;;
  deploy)
    run_build
    run_submit
    ;;
  *)
    echo "ERROR: Unknown command '$COMMAND'. Use: build | submit | deploy"
    exit 1
    ;;
esac
