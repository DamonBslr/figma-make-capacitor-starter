---
name: app-store-readiness-audit
description: >-
  Audit an iOS app for Apple App Store submission readiness. Checks Info.plist /
  app config, declared usage descriptions vs. actual SDK usage, account deletion,
  privacy policy, App Transport Security, encryption export compliance, privacy
  manifest, Sign in with Apple parity, app icon, and other Apple Review Guideline
  requirements. Produces a categorized report with evidence (file:line), blockers,
  risks, and required fixes. Trigger on "is my app ready for App Store / TestFlight",
  "audit my iOS app for Apple submission", "recheck the issues from the previous
  audit", or any request to validate a fix list from a prior audit.
allowed-tools: Bash Read Write Edit Glob Grep WebSearch
---

# App Store Readiness Audit (iOS)

Produce an evidence-backed audit of an iOS app against current Apple App Store
Review Guidelines. Works for any framework — Expo, React Native CLI, Capacitor,
native Swift/Xcode, Flutter.

## Procedure

### 1. Locate config sources

Identify where iOS config actually lives. Different frameworks store it differently:

| Framework | Primary config |
|---|---|
| Expo (managed) | `app.json` / `app.config.{js,ts}` (`expo.ios.infoPlist`, `expo.plugins`, `expo.ios.privacyManifests`) |
| Expo (prebuild) + RN CLI | `ios/<App>/Info.plist`, `ios/<App>/PrivacyInfo.xcprivacy`, `ios/<App>.xcodeproj/project.pbxproj` |
| Capacitor | `ios/App/App/Info.plist`, `capacitor.config.ts` |
| Native Xcode | `Info.plist`, `*.entitlements`, `project.pbxproj` |
| Flutter | `ios/Runner/Info.plist` |

Also check: `eas.json` (if present), root `package.json`, `.env*`, any
`privacy-policy*` / `terms*` files.

### 2. Run the checklist

Read [references/checklist.md](references/checklist.md) in full. Work through every item. For each item:

1. Search config + code for the relevant key, permission, or SDK usage.
2. Cross-reference: a usage description without matching SDK usage is a **risk**;
   an SDK in use without the matching usage description is a **blocker** (the app
   will crash on first prompt or be rejected).
3. Record evidence as `file:line` so the user can verify. Use `Bash` (grep/rg)
   and `Read` aggressively. Do not guess — open the file.

### 3. Verify against current Apple rules

Some requirements change over time (Privacy Manifest deadlines, Sign in with
Apple parity, account deletion enforcement). For any item where you are uncertain
whether the rule still applies as documented in this skill, run a `WebSearch`
against `developer.apple.com` for the current guideline. See
[references/apple-references.md](references/apple-references.md) for canonical URLs.

### 4. Produce the report

Organize all findings by severity, not by category — users care about what
blocks them first. Every finding must cite a `file:line` or explicitly state
"not found in repo — must be configured in App Store Connect". Do not mark
anything as compliant without evidence from a file. Do not invent guidelines;
if unsure, mark as "needs verification" and link the relevant `developer.apple.com`
page. Keep evidence quotes short (3 lines max).

Use this structure:

- **Resolved / Compliant** — one-line evidence per item with `file:line`.
- **Blockers (must fix before submission)** — for each: status, evidence, why
  it blocks (guideline / what Apple does), and a concrete required fix.
- **Risks (recommended, not strict blockers)** — same shape, framed as "should
  fix" or "reviewer may flag".
- **App Store Connect actions** — things the user must do in App Store Connect
  itself (Privacy Nutrition Label, screenshots, age rating, export compliance,
  encryption questionnaire). These are not in source control.
- **Summary** — blocker count, risk count, compliant count, single recommended
  next step.

End the report with a numbered list of 2–4 concrete follow-up fixes the agent
can apply directly. Do not start fixing without the user choosing one.

### 5. Re-audit (if the user says "recheck" or "revalidate")

Re-run the full checklist — do not trust the previous result, files may have
changed. For each previously-flagged item, explicitly state whether it is now
resolved or still a blocker/risk, with new evidence. Add any new blockers or
risks introduced since the last pass.

## Guardrails

- Never report a usage description as "missing" without grepping for the SDK
  that would require it — the SDK might not be present.
- Never mark account deletion as compliant just because a "Delete Account" button
  exists — verify it actually calls a delete API and clears server-side data.
- Never trust `app.json` alone in a prebuilt Expo project — once `expo prebuild`
  has run, the source of truth is `ios/<App>/Info.plist`.
- Never list every Apple guideline as a finding. Only report items with actual
  evidence in the repo or clear gaps in the repo.
- Never mark ATT as compliant if `NSUserTrackingUsageDescription` exists but no
  explicit `requestTrackingPermissionsAsync()` call is found — Apple requires an
  explicit ATT request; relying on AdMob's passive trigger is no longer sufficient
  (Guideline 2.1).
- Watch for ATT timing: if `requestTrackingPermissionsAsync()` is called before
  `SplashScreen.hideAsync()` or during module-load, iOS silently denies the
  request without showing the prompt.
- In Expo projects, `ios.locales` is ignored — Expo SDK 55's `withLocales` plugin
  only reads `expo.locales` (top-level). Permission strings in `ios.locales` are
  dropped during build, causing Guideline 4 rejections for mixed-language prompts.
