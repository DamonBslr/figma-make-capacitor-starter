# Native OAuth — human checklist

These steps touch external consoles and signing material. They must be done by a
person; the skill will not (and cannot safely) do them. Work top to bottom.

For step-by-step screenshots-level instructions, see `docs/social-auth-setup.md`
in the project root. This checklist is the quick-scan companion to that guide.

---

## What the agent does for you (before handing off)

- Installs `@capgo/capacitor-social-login`
- Writes the URL scheme into `ios/.../Info.plist` and `android/.../AndroidManifest.xml`
- Implements `signInWithGoogle()` and `signInWithApple()` in `packages/core/src/auth/`
- Adds `VITE_GOOGLE_WEB_CLIENT_ID` to `apps/mobile/.env.example` with a placeholder
- Generates the Apple JWT if you supply the `.p8` path and Team ID:
  `node scripts/generate-apple-jwt.js /path/to/AuthKey_KEYID.p8 YOUR_TEAM_ID`
- Runs `cap sync` after everything is wired

---

## Human steps — Google

- [ ] Google Cloud Console → new project (or reuse existing)
- [ ] OAuth consent screen: External, add `openid email profile` scopes, add test user
- [ ] Create **three** OAuth client IDs: Web, iOS, Android
  - Web: add Supabase callback as authorized redirect URI
  - iOS: bundle ID only, no secret
  - Android: package name + SHA-1 fingerprint of your signing key
    (see `docs/social-auth-setup.md` §1c for keystore SHA-1 options)
- [ ] Add `VITE_GOOGLE_WEB_CLIENT_ID=<web-client-id>` to `apps/mobile/.env`

## Human steps — Apple

- [ ] Apple Developer → Identifiers → enable "Sign in with Apple" on your App ID
- [ ] Create a Services ID (`<bundle>.siwa`), add Supabase callback as return URL
- [ ] Create a Sign in with Apple key, download the `.p8` (one-time download)
- [ ] Generate the Apple client secret JWT (browser tool or `scripts/generate-apple-jwt.js`)
  — expires every 180 days; set a calendar reminder

## Human steps — Supabase dashboard

- [ ] Auth → Providers → Google: paste Web Client ID + Secret + Android Client ID
- [ ] Auth → Providers → Apple: paste bundle ID + Services ID + JWT secret
- [ ] Auth → URL Configuration → Redirect URLs: add `<bundle-id>://**`

## Verify

- [ ] Run `cap sync` (agent does this, but re-run after any Info.plist/manifest edits)
- [ ] Build to a **real device** — OAuth flows do not complete in web preview or Simulator
- [ ] Test Google sign-in end to end
- [ ] Test Apple sign-in end to end
- [ ] Restart app and confirm session persists (Preferences-backed storage)

---

## Common failures

| Symptom | Fix |
|---|---|
| `redirect_uri_mismatch` | Supabase callback URL in Google console must be `https://<ref>.supabase.co/auth/v1/callback` with no trailing slash |
| Sign-in sheet appears, then nothing | Deep-link scheme mismatch — check `Info.plist` and `AndroidManifest.xml`; run `cap sync` |
| Apple `invalid_client` | Services ID identifier or return URL doesn't match exactly what's in Supabase |
| Apple: user created but no session | JWT wrong or expired — regenerate and re-paste into Supabase |
| Android `ApiException: 10` | SHA-1 fingerprint in Google console doesn't match your signing key |
| Session lost after restart | `@capacitor/preferences` storage adapter not wired in `packages/core/src/supabase/client.ts` |

Never store any client secret or `.p8` key in the repo.
