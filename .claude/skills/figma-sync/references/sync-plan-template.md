# SYNC_PLAN.md template

The gate artifact. Written at the repo root BEFORE any file is touched, then shown
to the user for approval (REVIEW 7). It must be self-contained: a reviewer should be
able to approve or reject from this file alone, without re-running the diff.

Fill every section. The per-file table must account for every file in
`git diff --stat <from_commit>..<to_commit>` — no file dropped, no file double-listed.

---

# Figma Sync Plan

- **from_commit:** `<short-sha>` (current anchor, FIGMA_SOURCE.json `synced_commit`)
- **to_commit:** `<short-sha>` (`origin/<branch>` HEAD)
- **branch:** `<branch>`
- **commits:** `<n>` new upstream commits
- **date:** `<YYYY-MM-DD>`
- **Boundary check:** This plan writes ONLY into `packages/ui/` plus the
  `// TODO(human-review)` stubs listed under Backend follow-ups. It touches nothing
  in `apps/mobile/`, nothing else in `packages/core/`, and nothing in `.figma-src/`.

## Upstream commits
Short list of the new commits being synced (`git log --oneline <from>..<to>`), so the
reviewer sees the design intent behind the file changes.

## Per-file mapping
| upstream file | change type | classification | target in packages/ui | notes |
|---------------|-------------|----------------|------------------------|-------|
| `src/screens/Profile.tsx` | modified | ui-only | `packages/ui/src/ProfileScreen.tsx` | copy hunk near-verbatim |
| `src/screens/Feed.tsx` | modified | ui+stub | `packages/ui/src/FeedScreen.tsx` | UI delta only; new fetch region → stub note in `packages/core/src/feed/useFeed.ts` |
| `src/screens/Wallet.tsx` | added | backend-follow-up | `packages/ui/src/WalletScreen.tsx` | new stub `packages/core/src/wallet/useWallet.ts` → /wire-supabase |
| `src/components/OldBanner.tsx` | deleted | delete | `packages/ui/src/OldBanner.tsx` | remove + drop from `index.ts` barrel |
| `vite.config.ts` | modified | ignore | — | build config; lives in apps/mobile, hand-owned |

- **change type:** added / modified / deleted / renamed (from the diff).
- **classification:** ui-only / ui+stub / backend-follow-up / delete / ignore (see
  `mapping-heuristics.md`).

## Barrel updates
List the `packages/ui/src/index.ts` exports to add / remove / rename.

## Fonts
Any `fonts.googleapis.com` references the diff reintroduced and the Fontsource
package each was converted to — or "none".

## Backend follow-ups (handoff to /wire-supabase)
For each ui+stub and backend-follow-up:
- **stub:** `packages/core/src/<path>` — the `// TODO(human-review)` added.
- **why:** the upstream change that implies it (new data source, new persisted shape).
- **next:** run `/wire-supabase` to spec + implement this stub (do NOT wire it here).

Or "none — pure UI sync".

## Open questions / risks
Anything the reviewer should weigh in on: an exported signature that the design forces
to change, an upstream rename that's ambiguous against our split, a removed screen
that core still references.
