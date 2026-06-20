---
description: Bootstrap a production Capacitor app from a Figma Make repo (initial transformation, run once)
argument-hint: <figma-make-repo-url> [AppName] [app.bundle.id]
allowed-tools: Bash Read Write Edit Glob Grep
---

Perform the **initial transformation** using the `figma-make-to-capacitor` skill.

Inputs:
- Figma Make repo: $1
- App name: $2 (ask if empty)
- Bundle id: $3 (ask if empty)

Rules:
- Follow the skill's procedure in order; read its `references/architecture.md` before moving code.
- `.figma-src/` is read-only — never push back to the Figma repo.
- Leave every backend touchpoint as a typed stub for human review; never fabricate auth or secrets.
- Stop at `TRANSFORMATION_REPORT.md`. Do not run native builds, signing, or store submission.
