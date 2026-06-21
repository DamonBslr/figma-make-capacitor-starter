# Social sign-in setup (Google + Apple)

Do this after email/password auth is confirmed working. Test on a real device —
OAuth flows do not complete in the browser preview or iOS Simulator.

---

## 1. Google

### 1a. Create a Google Cloud project (skip if you already have one)

1. Go to [console.cloud.google.com](https://console.cloud.google.com).
2. Click the project dropdown at the top (next to "Google Cloud") → **New Project**.
3. Name it `Muse`, click **Create**.
4. Make sure the new project is selected in the dropdown before continuing.

### 1b. OAuth consent screen (required before creating any client IDs)

Left sidebar → **APIs & Services** → **OAuth consent screen**.

1. Choose **External** (works for any Google account, not just your org) → **Create**.
2. Fill in:
   - **App name**: `Muse`
   - **User support email**: your email
   - **Developer contact information**: your email
3. Click **Save and Continue**.
4. **Scopes** screen: click **Add or Remove Scopes**, check `openid`, `email`, `profile` → **Update** → **Save and Continue**.
5. **Test users** screen: click **+ Add Users**, add your own Google email address → **Save and Continue**.
6. Review summary, click **Back to Dashboard**.

> The app stays in "Testing" mode during development, which limits it to your test users. You publish it later when submitting to the stores.

### 1c. Create the three OAuth client IDs

Left sidebar → **APIs & Services** → **Credentials** → **+ Create Credentials** → **OAuth client ID**.

Repeat this three times, once per client type below.

---

**Client 1 — Web application** (used by Supabase to exchange the token)

- **Application type**: Web application
- **Name**: `Muse Supabase`
- **Authorized JavaScript origins**: click **+ Add URI**, enter:
  ```
  https://<your-ref>.supabase.co
  ```
- **Authorized redirect URIs**: click **+ Add URI**, enter:
  ```
  https://<your-ref>.supabase.co/auth/v1/callback
  ```
  Replace `<your-ref>` with your Supabase project ref (the ID in your project URL, e.g. `fmrlygpyfraaneumozim`).
- Click **Create**.
- A popup shows your **Client ID** and **Client Secret**. Copy both now — you need them for Supabase in step 3a.

---

**Client 2 — iOS**

- **Application type**: iOS
- **Name**: `Muse iOS`
- **Bundle ID**: `com.damonbasler.muse`
- (No JS origins or redirect URI fields — iOS clients don't have them.)
- Click **Create**.
- Copy the **Client ID** (looks like `123456789-abc.apps.googleusercontent.com`).

> The iOS client has no secret. The secret lives only on the Web client.

---

**Client 3 — Android**

- **Application type**: Android
- **Name**: `Muse Android`
- **Package name**: `com.damonbasler.muse`
- **SHA-1 certificate fingerprint**: depends on how you distribute the app:

  **Google Play distribution** — Google manages signing for you. Get the fingerprint from:
  [Google Play Console](https://play.google.com/console) → your app → **Setup** → **App integrity** → **App signing** tab → copy the **SHA-1 certificate fingerprint** under "App signing key certificate".

  **Local APK / direct distribution** — you need the SHA-1 from your keystore.
  `keytool` requires Java; if you get "Unable to locate a Java Runtime" on macOS,
  use one of these instead:

  **Option A — Android Studio terminal (no Java install needed)**
  Android Studio ships its own JDK. Open the project (`apps/mobile/android`) in
  Android Studio, open its built-in terminal (**View → Tool Windows → Terminal**),
  then run:
  ```bash
  ./gradlew signingReport
  ```
  Look for the `debug` variant block and copy the **SHA1** line.

  **Option B — install Java via Homebrew, then generate the keystore**
  ```bash
  brew install --cask temurin
  ```
  The debug keystore at `~/.android/debug.keystore` is created automatically the
  first time Android Studio builds the project. If it doesn't exist yet, either:

  - Open `apps/mobile/android` in Android Studio and do **Build → Make Project** once, then rerun `keytool`, or
  - Generate it manually right now:
    ```bash
    keytool -genkey -v \
      -keystore ~/.android/debug.keystore \
      -alias androiddebugkey \
      -keyalg RSA -keysize 2048 \
      -validity 10000 \
      -storepass android -keypass android \
      -dname "CN=Android Debug,O=Android,C=US"
    ```
  Then read the SHA-1:
  ```bash
  keytool -keystore ~/.android/debug.keystore -list -v
  ```
  Copy the **SHA1** line (format: `AA:BB:CC:...`).
- (No JS origins or redirect URI fields — Android clients don't have them.)
- Click **Create**.

---

### What you now have from Google

| Item | Where to use it |
|---|---|
| Web Client ID | Supabase dashboard → Google provider → **Client ID** field |
| Web Client Secret | Supabase dashboard → Google provider → **Client Secret** field |
| Web Client ID (again) | `apps/mobile/.env` → `VITE_GOOGLE_WEB_CLIENT_ID` |

---

## 2. Apple

Apple requires "Sign in with Apple" on iOS whenever your app offers any third-party login option.

### 2a. Register the App ID and enable Sign in with Apple

1. Go to [developer.apple.com](https://developer.apple.com) → sign in → **Account** (top right).
2. Click **Certificates, Identifiers & Profiles** in the left sidebar.
3. Left sidebar → **Identifiers**.

**If `com.damonbasler.muse` is not in the list yet**, register it first:
- Click **+** (top right) → **App IDs** → **App** → **Continue**
- **Description**: `Muse`
- **Bundle ID**: select **Explicit** → enter `com.damonbasler.muse`
- Scroll down, check **Sign in with Apple**
- Click **Continue** → **Register**

**If `com.damonbasler.muse` already exists**, click it in the list, then:
4. In the **Capabilities** list, find **Sign in with Apple**, check the checkbox on the left.
5. Click **Save** at the top right. Confirm in the popup.

### 2b. Create a Services ID

A Services ID is Apple's "client ID" — it identifies your app to Supabase.

1. Still in **Certificates, Identifiers & Profiles** → left sidebar → **Identifiers**.
2. Click **+** (top right) → select **Services IDs** → **Continue**.
3. Fill in:
   - **Description**: `Muse`
   - **Identifier**: `com.damonbasler.muse.siwa`
4. Click **Continue** → **Register**.
5. Back in the Identifiers list, click `com.damonbasler.muse.siwa` to open it.
6. Check the **Sign in with Apple** checkbox → click **Configure** (appears next to it).
7. In the configuration panel:
   - **Primary App ID**: select `com.damonbasler.muse`
   - **Domains and Subdomains**: `<your-ref>.supabase.co`
   - **Return URLs**: `https://<your-ref>.supabase.co/auth/v1/callback`
8. Click **Next** → **Done** → **Continue** → **Save**.

### 2c. Create a Sign in with Apple key

1. Left sidebar → **Keys** → **+** (top right).
2. Fill in:
   - **Key Name**: `Muse Sign in with Apple`
3. Check the **Sign in with Apple** checkbox → click **Configure** next to it.
4. **Primary App ID**: select `com.damonbasler.muse` → **Save**.
5. Click **Continue** → **Register**.
6. On the confirmation screen, note your **Key ID** (10-character alphanumeric string).
7. Click **Download** — this downloads `AuthKey_<KeyID>.p8`. **This is the only time you can download it.**
8. Store the `.p8` file somewhere safe outside the repo. You will paste its contents into Supabase.

### Where to find your Apple Team ID

Top-right corner of [developer.apple.com](https://developer.apple.com) when logged in, shown in small text under your name. Format: 10 uppercase alphanumeric characters, e.g. `A1B2C3D4E5`.

---

## 3. Supabase dashboard

Go to [supabase.com/dashboard](https://supabase.com/dashboard) → select your project.

### 3a. Enable Google

Left sidebar → **Authentication** → **Providers** → scroll to **Google** → click to expand → toggle **Enable Sign in with Google** on.

| Field | Value |
|---|---|
| **Authorized Client IDs (for Android)** | The Android client ID from step 1c |
| **Client ID** | The Web client ID from step 1c |
| **Client Secret** | The Web client secret from step 1c |

Click **Save**.

### 3b. Enable Apple

Left sidebar → **Authentication** → **Providers** → scroll to **Apple** → click to expand → toggle **Enable Sign in with Apple** on.

| Field | Value |
|---|---|
| **Client IDs** | `com.damonbasler.muse` (bundle ID for native sign-in). Add `com.damonbasler.muse.siwa` as a second entry if you set up a Services ID. |
| **Secret Key** | A signed JWT — see generation command below |

Apple's client secret is a signed JWT that expires every 6 months. Two ways to generate it:

**Option A — Supabase browser tool (simplest, no code)**
Go to [supabase.com/docs/guides/auth/social-login/auth-apple#generate-a-client_secret](https://supabase.com/docs/guides/auth/social-login/auth-apple#generate-a-client_secret) and use the in-page tool. Use Firefox or Chrome (not Safari). Fill in:

| Tool field | Value |
|---|---|
| **Team ID** | Your 10-character Apple Team ID (top-right of developer.apple.com) |
| **Key ID** | `5N72N6BZJ9` (from the filename `AuthKey_5N72N6BZJ9.p8`) |
| **Services ID** | `com.damonbasler.muse.siwa` (the identifier you registered in step 2b — NOT the bundle ID) |
| **Private Key (.p8)** | Upload or paste the contents of `AuthKey_5N72N6BZJ9.p8` |

The JWT is generated entirely in your browser — nothing is sent to any server.

**Option B — script in this repo**
```bash
node scripts/generate-apple-jwt.js /path/to/AuthKey_KEYID.p8 YOUR_TEAM_ID
```
Replace `YOUR_TEAM_ID` with the 10-character ID shown top-right on developer.apple.com. The Key ID is extracted automatically from the filename. The script prints the JWT and its expiry date.

The output string is the **Secret Key** to paste into Supabase.

> The JWT expires after 180 days. Set a reminder to regenerate before then — either rerun the script or use the Supabase browser tool again.

> The JWT expires — the `+180d` above gives 6 months. You'll need to regenerate and update it in Supabase before it expires.

Click **Save**.

### 3c. Add the deep-link redirect URL

Left sidebar → **Authentication** → **URL Configuration**.

Under **Redirect URLs**, click **Add URL** and enter:
```
com.damonbasler.muse://**
```
Click **Save**.

---

## 4. Add the Google client ID to your .env

In `apps/mobile/.env`, set:
```
VITE_GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
```
Use the **Web** client ID from step 1c (not the iOS or Android one). Restart the dev server after editing `.env`.

---

## 5. Sync native projects and test

```bash
# From apps/mobile — picks up the new plugin's native code:
npx cap sync

# Then open the native project and build to a physical device:
# iOS: open apps/mobile/ios/App/App.xcworkspace in Xcode → select a real device → Run
# Android: open apps/mobile/android in Android Studio → select a real device → Run
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Google: `redirect_uri_mismatch` | Redirect URI in Google Cloud Console doesn't exactly match what Supabase sends | In step 1c Web client, confirm the redirect URI is `https://<ref>.supabase.co/auth/v1/callback` with no trailing slash |
| Google: sign-in sheet appears but then nothing happens | The deep-link `com.damonbasler.muse://` wasn't received by the app | Confirm `CFBundleURLTypes` in `Info.plist` and `<intent-filter>` in `AndroidManifest.xml` both use scheme `com.damonbasler.muse` (already done by the skill); run `cap sync` again |
| Apple: `invalid_client` | Services ID or return URL mismatch | Re-check step 2b: the Services ID identifier must match exactly what's in Supabase, and the return URL must be `https://<ref>.supabase.co/auth/v1/callback` |
| Apple: sign-in completes but user not created in Supabase | Secret JWT is wrong or expired | Regenerate the JWT with the `jwt encode` command and re-paste into Supabase; check Key ID and Team ID are correct |
| Session lost after app restart | Unrelated to social auth | Verify `@capacitor/preferences` storage adapter is wired in `packages/core/src/supabase/client.ts` |
| Android: `ApiException: 10` | SHA-1 fingerprint mismatch | Re-run the `keytool` command and compare the output SHA1 to what's registered on the Android client in Google Cloud Console |

---

**Security:** the `.p8` key file, Web client secret, and any private keys never go in the repo.
The app only holds public client IDs (the strings ending in `.apps.googleusercontent.com` and `com.damonbasler.muse.siwa`).
