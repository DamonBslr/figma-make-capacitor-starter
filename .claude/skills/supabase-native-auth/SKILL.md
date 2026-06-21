---
name: supabase-native-auth
description: >-
  Step 4 (gated) of the Supabase backend — native Google/Apple sign-in for the
  Capacitor app. Installs the native social-login plugin, writes the custom URL
  scheme into iOS Info.plist and Android AndroidManifest, wires the deep-link →
  signInWithIdToken handler, and produces a precise human checklist for the parts
  that must be done by a person (provider consoles, Supabase dashboard). Trigger on
  "add Google/Apple sign-in", "set up native OAuth", or the /wire-supabase orchestrator.
allowed-tools: Bash Read Write Edit Glob Grep
---

# Native social sign-in (gated)

Native OAuth is the one part that cannot be fully automated and shouldn't be — it
spans provider consoles and signing that require a human. This skill does the
in-repo scaffolding and hands you an exact checklist for the rest.

Do this AFTER email/password auth works (via supabase-wire-stub on `useAuth`).

## What this skill does (automatable)
1. Install the native social-login plugin: `@capgo/capacitor-social-login`
   (actively maintained; preferred over the now-stale community plugins).
2. Register the custom URL scheme `com.muse.app` (or the app's bundle id):
   - iOS: add a `CFBundleURLTypes` entry to `apps/mobile/ios/App/App/Info.plist`.
   - Android: add an `<intent-filter>` with the scheme to the main activity in
     `apps/mobile/android/app/src/main/AndroidManifest.xml`.
3. Implement the sign-in handlers in `packages/core/src/auth/`: call the plugin to
   get a Google/Apple ID token, then `supabase.auth.signInWithIdToken(...)`.
   Keep `useAuth`'s exported interface unchanged — only the OAuth method bodies change.
4. Wire the deep-link listener in the `apps/mobile` shell to complete the callback.

## Human checklist (cannot be automated)
Surface `references/human-checklist.md` to the user and STOP; do not attempt these:
- Google Cloud console: OAuth consent screen, three client IDs (Web/iOS/Android).
- Apple Developer: enable Sign in with Apple on App ID, create Services ID + key (.p8).
- Supabase dashboard → Auth → Providers: enable Google/Apple, paste IDs/secrets.
- Supabase dashboard → Auth → URL Configuration: add redirect `<bundle-id>://**`.
- Android signing: SHA-1 fingerprint of signing key registered on the Android client.

For step-by-step instructions see `docs/social-auth-setup.md` in the project root.
That file was written from a real run and covers every console screen in detail.

## Guardrails
- NEVER enter credentials into provider consoles or the Supabase dashboard, and
  never create accounts or OAuth clients on the user's behalf. Output the steps.
- Client secrets and signing keys never go in the repo. The app only ever holds the
  public client IDs that belong in native config.
- Expect iteration: redirect-URI mismatches and deep-link misconfig are the usual
  failure points. Treat a failed first attempt as normal and check the checklist.
