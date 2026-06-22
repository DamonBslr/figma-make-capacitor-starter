#!/usr/bin/env bash
# pending_commits.sh — list the Figma Make commits not yet synced into the app.
# Reads FIGMA_SOURCE.json (the anchor) so you never paste a SHA by hand.
# Read-only: it only fetches and logs; it never writes the anchor or .figma-src.
#
#   ./pending_commits.sh                 # from the app repo root
#   ./pending_commits.sh --no-fetch      # skip 'git fetch' (use already-fetched refs)
#
# Output: oldest→newest list of pending commits (the order to apply them in),
# preceded by the resolved from/to SHAs.

set -euo pipefail

ANCHOR="FIGMA_SOURCE.json"
FIGMA_DIR=".figma-src"
DO_FETCH=1
[ "${1:-}" = "--no-fetch" ] && DO_FETCH=0

[ -f "$ANCHOR" ] || { echo "✗ $ANCHOR not found. Run /set-figma-source first (from the app repo root)." >&2; exit 1; }
[ -d "$FIGMA_DIR/.git" ] || { echo "✗ $FIGMA_DIR is not a git clone. Run /set-figma-source to clone it." >&2; exit 1; }

# Read branch + synced_commit from the anchor — jq if present, else a portable sed fallback.
read_field() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$key" '.[$k] // empty' "$ANCHOR"
  else
    sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$ANCHOR" | head -1
  fi
}

BRANCH="$(read_field branch)"; BRANCH="${BRANCH:-main}"
SYNCED="$(read_field synced_commit)"
[ -n "$SYNCED" ] || { echo "✗ synced_commit missing/empty in $ANCHOR. Re-run /set-figma-source." >&2; exit 1; }

[ "$DO_FETCH" -eq 1 ] && git -C "$FIGMA_DIR" fetch --quiet origin

# Validate the anchor SHA still exists upstream (force-mirrored repos can rewrite history).
if ! git -C "$FIGMA_DIR" cat-file -e "${SYNCED}^{commit}" 2>/dev/null; then
  echo "✗ anchor commit $SYNCED not found in $FIGMA_DIR. The Figma repo may have rewritten history — re-run /set-figma-source." >&2
  exit 1
fi

HEAD_SHA="$(git -C "$FIGMA_DIR" rev-parse "origin/${BRANCH}")"
COUNT="$(git -C "$FIGMA_DIR" rev-list --count "${SYNCED}..origin/${BRANCH}")"

echo "anchor (from): $(git -C "$FIGMA_DIR" rev-parse --short "$SYNCED")  on branch ${BRANCH}"
echo "head   (to):   $(git -C "$FIGMA_DIR" rev-parse --short "$HEAD_SHA")"
echo "pending:       ${COUNT} commit(s)"
echo

if [ "$COUNT" -eq 0 ]; then
  echo "✓ Already up to date — nothing to sync."
  exit 0
fi

echo "Apply in this order (oldest → newest):"
git -C "$FIGMA_DIR" log --oneline --reverse "${SYNCED}..origin/${BRANCH}"
echo
echo "Stepwise:  /sync-figma --to <sha>   (one commit at a time)"
echo "All at once: /sync-figma"
