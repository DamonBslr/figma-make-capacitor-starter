---
description: Create/repair the FIGMA_SOURCE.json anchor that /sync-figma diffs from
argument-hint: [figma-repo-url] [commit-sha] [branch]
allowed-tools: Bash Read Write Edit Glob Grep
---

Establish (or repair) the **Figma sync anchor** for this app: the committed
`FIGMA_SOURCE.json` that records which upstream Figma Make commit `packages/ui`
currently reflects. `/sync-figma` diffs forward from this commit, so it must be the
commit the UI actually matches — usually the one the initial transformation used,
NOT the Figma repo's latest HEAD.

Inputs (ask / confirm any not given):
- Figma Make repo URL: $1
- Commit SHA the current `packages/ui` reflects: $2
- Branch: $3 (default `main`)

## Preflight — sanity check the repo
- Confirm this looks like a transformed app, not the kit: `test -d packages/ui`.
  If `packages/ui` is missing, STOP and tell the user this command runs inside a
  transformed app (run `/init-from-figma` first).
- If `FIGMA_SOURCE.json` already exists, read it and show the user the current
  `synced_commit`. Treat this run as a **repair**: confirm before overwriting, and
  preserve `last_sync_pr` if set.

## Step 1 — inspect .figma-src/
Check what's already there and reuse it rather than re-cloning:

```bash
test -d .figma-src && echo "present" || echo "absent"
git -C .figma-src rev-parse --is-inside-work-tree 2>/dev/null && \
  git -C .figma-src remote get-url origin && \
  git -C .figma-src branch --show-current && \
  git -C .figma-src log --oneline -1
```

- **If `.figma-src/` is a git repo:** derive the repo URL and branch from its
  `origin` remote — only ask the user if `$1`/`$3` disagree with what's there.
  Offer its current HEAD SHA as the default for `synced_commit` (the user can
  override with the commit they actually transformed from).
- **If `.figma-src/` is absent:** you need the URL (`$1` or ask), then clone it
  read-only — it is gitignored upstream source, never edit or push to it:
  ```bash
  git clone <url> .figma-src
  ```
- **If `.figma-src/` exists but is NOT a git repo** (a plain copy): tell the user;
  to get real diffs it should be a clone. Offer to back it aside and re-clone, or
  proceed URL-only (the anchor still records the SHA, and `/sync-figma` re-clones).

Then make sure refs are current: `git -C .figma-src fetch origin`.

## Step 2 — resolve and VERIFY the commit
Resolve the SHA the user gave (or the chosen default) and confirm it actually
exists in the Figma repo — a typo here silently breaks the first sync:

```bash
git -C .figma-src rev-parse --verify <sha>^{commit}     # full 40-char SHA on success
git -C .figma-src cat-file -t <sha>                      # must print: commit
```

If it does not resolve, STOP and ask the user for a valid SHA (don't write a guess).
Use the full resolved SHA in the file, not the short form.

## Step 3 — write FIGMA_SOURCE.json
Write it at the repo root:

```json
{
  "repo": "<figma-repo-url>",
  "branch": "<branch>",
  "synced_commit": "<full-resolved-sha>",
  "synced_at": "<YYYY-MM-DD today>",
  "last_sync_pr": null
}
```
(`last_sync_pr` stays `null` until the first real `/sync-figma` opens a PR — preserve
an existing value on a repair run.)

## Step 4 — report, don't commit
Show the written file and tell the user:
- the anchor is set at `<short-sha>`;
- `.figma-src/` is `origin/<branch>` at HEAD `<head-sha>`, so the next `/sync-figma`
  will diff `<synced_commit>..origin/<branch>` — if HEAD is ahead, name how many
  commits are pending (`git -C .figma-src log --oneline <sha>..origin/<branch> | wc -l`);
- `.figma-src/` is gitignored and stays out of version control; only
  `FIGMA_SOURCE.json` is committed.

Do NOT commit automatically — leave `FIGMA_SOURCE.json` staged-or-unstaged for the
user to review and commit (it is the one anchor for every future sync).
