# Native OAuth — human checklist

These steps touch external consoles and signing material. They must be done by a
person; the skill will not (and cannot safely) do them. Work top to bottom.

## Google
1. Google Cloud Console → APIs & Services → Credentials.
2. Create OAuth client IDs:
   - Web (used by Supabase as the OAuth client),
   - iOS (bundle id `com.muse.app`),
   - Android (package name + signing-key SHA-1; get SHA-1 from your keystore).
3. Copy the Web client ID + secret into Supabase → Auth → Providers → Google.

## Apple (required if you offer any third-party login on iOS)
1. Apple Developer → Certificates, Identifiers & Profiles.
2. Enable "Sign in with Apple" on the App ID.
3. Create a Services ID and a Sign in with Apple key (.p8).
4. Put the Services ID + key details into Supabase → Auth → Providers → Apple.

## Supabase dashboard
1. Authentication → Providers: enable Google and Apple, paste the IDs/secrets above.
2. Authentication → URL Configuration: add redirect URL `com.muse.app://**`.

## Signing / deep links
- iOS: confirm the URL scheme in Info.plist matches `com.muse.app`.
- Android: confirm the `<intent-filter>` scheme matches, and that the signing key's
  SHA-1 is registered on the Google Android client.

## Verify
- Build to a real device (OAuth flows don't complete reliably in web preview).
- Test Google and Apple sign-in end to end; confirm the session persists after an
  app restart (Preferences-backed storage).

## Common failures
- `redirect_uri_mismatch`: the redirect in the console/dashboard doesn't match the
  scheme. Re-check `com.muse.app://**` everywhere.
- Sign-in completes but app does nothing: deep-link listener not wired, or
  `detectSessionInUrl` left on. The handler must exchange the token explicitly.
- Never store any client secret or `.p8` key in the repo.
