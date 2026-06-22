# iOS App Store Audit Checklist

Work through every section. For each item: locate evidence, classify as ✅ / ⚠️ / ❌, record `file:line`.

---

## 1. Bundle & Identity

- **Bundle identifier** — `expo.ios.bundleIdentifier` or `CFBundleIdentifier`. Must be reverse-DNS, registered in Apple Developer, matches App Store Connect record.
- **Display name** — `expo.name` / `CFBundleDisplayName`. ≤ 30 chars on App Store, ≤ 12 visually on home screen ideal.
- **Version** — `expo.version` / `CFBundleShortVersionString`. Semantic.
- **Build number** — must increment per upload (or `autoIncrement: true` in `eas.json`).
- **Minimum iOS version** — `ios.deploymentTarget` / `IPHONEOS_DEPLOYMENT_TARGET`. Apple requires building with the current Xcode SDK; deployment target should be reasonable (typically iOS 15+ as of 2026).
- **Owner / team ID** — present in `eas.json` or Xcode signing.

## 2. App Icon & Launch

- **App icon** — `expo.icon` or `Assets.xcassets/AppIcon.appiconset`. Must be 1024×1024 (App Store) and **not** the default Expo / template icon. Open it visually.
- **No alpha channel** on the 1024 icon (Apple rejects PNG with alpha).
- **Launch screen / splash** — present, branded, not a placeholder.
- **Supported orientations** — match what the UI actually supports (`expo.orientation` or `UISupportedInterfaceOrientations`).
- **`supportsTablet`** — set deliberately (`true`/`false`); if `true`, app must work on iPad layout.

## 3. Usage Descriptions (Info.plist `NS*UsageDescription` keys)

For **every** SDK / permission used, the matching key MUST exist with a clear, user-facing reason. Missing key = guaranteed crash on first prompt or rejection.

Cross-reference: search the codebase for the SDK, then verify the key exists.

| If you find this in code… | Required Info.plist key |
|---|---|
| `expo-camera`, `react-native-vision-camera`, `AVCaptureDevice` | `NSCameraUsageDescription` |
| `expo-image-picker` (camera) | `NSCameraUsageDescription` |
| `expo-image-picker` (library) | `NSPhotoLibraryUsageDescription` |
| Saving photos | `NSPhotoLibraryAddUsageDescription` |
| `expo-microphone`, mic recording | `NSMicrophoneUsageDescription` |
| `expo-location`, `CLLocationManager` | `NSLocationWhenInUseUsageDescription` (+ `NSLocationAlwaysAndWhenInUseUsageDescription` if background) |
| `expo-contacts` | `NSContactsUsageDescription` |
| `expo-calendar` | `NSCalendarsUsageDescription` (+ `NSRemindersUsageDescription`) |
| `expo-media-library` | `NSPhotoLibraryUsageDescription` |
| `expo-notifications` (iOS push/local) | `NSUserNotificationsUsageDescription` |
| `expo-tracking-transparency`, IDFA | `NSUserTrackingUsageDescription` |
| `react-native-bluetooth*`, `CBCentralManager` | `NSBluetoothAlwaysUsageDescription` |
| `react-native-nfc-manager` | `NFCReaderUsageDescription` |
| FaceID, `expo-local-authentication` | `NSFaceIDUsageDescription` |
| Speech recognition | `NSSpeechRecognitionUsageDescription` |
| Motion / pedometer | `NSMotionUsageDescription` |
| HomeKit | `NSHomeKitUsageDescription` |
| Siri | `NSSiriUsageDescription` |
| `@kingstinct/react-native-healthkit`, HealthKit | `NSHealthShareUsageDescription` (read) + `NSHealthUpdateUsageDescription` (write) |

**Rules for the description string:**
- Must explain *why* in user-facing language. "Required for app" → reject.
- Must mention the actual feature (e.g. "to attach a photo to your message").
- For HealthKit, enumerate the specific data types (Apple reviewers expect this).

## 4. Capabilities & Entitlements

- **Sign in with Apple** — required if the app offers any other third-party login (Google, Facebook, Twitter, etc.) per Guideline 4.8. Check for `expo-apple-authentication` / `usesAppleSignIn: true` and matching entitlement.
- **Push notifications** — if used, `aps-environment` entitlement set, APNs key/cert configured.
- **Associated domains** — `applinks:` entries match the universal-link domain serving `apple-app-site-association`.
- **HealthKit** — `com.apple.developer.healthkit` entitlement.
- **In-App Purchase** — `com.apple.developer.in-app-payments` if selling digital goods.
- **App Groups, iCloud, CarPlay, etc.** — only declared if actually used.

## 5. App Tracking Transparency (ATT) — Critical iOS 14.5+

**If the app uses AdMob, Firebase Analytics, Facebook SDK, Amplitude, Mixpanel, or any SDK that accesses IDFA for cross-app tracking, ATT is MANDATORY.**

### 5.1 Required Package & Description

- **`expo-tracking-transparency`** (or equivalent native implementation) — must be installed if tracking occurs.
- **`NSUserTrackingUsageDescription`** — must be present in `Info.plist` / `expo.ios.infoPlist` with a clear, user-facing reason. Template strings like "This identifier will be used to show you more relevant ads" may be rejected under Guideline 4 (see 5.4 below).

### 5.2 Explicit ATT Request (Common Blocker)

Apple requires an **explicit call** to `requestTrackingPermissionsAsync()` (or native `ATTrackingManager.requestTrackingAuthorization()`) **before** initializing any tracking SDK (AdMob, Firebase, etc.).

**Blocker pattern:** Relying on the AdMob SDK's passive `MobileAds().initialize()` to trigger ATT stopped working reliably on iPadOS 26.4+. Apps without an explicit ATT call are rejected under Guideline 2.1 ("unable to locate the App Tracking Transparency permission request").

**Evidence to check:**
```typescript
// ❌ WRONG — no explicit ATT, only ad init
initMobileAds();

// ✅ CORRECT — ATT first, then ads
await requestTrackingPermissionsAsync();
initMobileAds();
```

Grep for `requestTrackingPermissionsAsync` or `requestTrackingAuthorization`. If not found but ads/tracking SDKs are present → **BLOCKER**.

### 5.3 ATT Timing — UIApplicationStateActive Requirement (Critical)

iOS **silently denies** ATT requests made before the app reaches `UIApplicationStateActive`. This happens if you call ATT:
- During module-load (top-level)
- In a `useEffect` before the splash screen hides
- Before the UIWindow is fully attached

**Symptoms:** ATT prompt never appears, app never shows in Settings → Privacy & Security → Tracking, reviewer reports "unable to locate" the prompt.

**Fix pattern (React Native / Expo):**
```typescript
// ✅ CORRECT — wait for splash + app active state
useEffect(() => {
  (async () => {
    await SplashScreen.hideAsync();
    // Now app is definitely active and UI is ready
    await requestTrackingPermissionsAsync();
    initMobileAds();
  })();
}, [user, loading]); // in AuthGuard or similar
```

Or use `AppState.addEventListener('change', ...)` to wait for `'active'` before calling.

**Evidence to check:** Find where `requestTrackingPermissionsAsync` is called. If it fires before `SplashScreen.hideAsync()` or during initial module evaluation → **BLOCKER**.

### 5.4 Permission String Localization (Guideline 4)

Apple rejects apps where permission descriptions don't match the device language. iOS renders the ATT prompt's system text (title, buttons) in the device language. If your description is in English but the device is set to German, you'll get:

> **Guideline 4 — Design**: The app's permission requests are not written in the same language as the app's localization.

**Fix:** Use `expo.locales` (top-level in `app.json`, NOT `ios.locales`) to provide translated `NSUserTrackingUsageDescription` strings:

```json
{
  "expo": {
    "locales": {
      "de": "./assets/locales/de.json",
      "fr": "./assets/locales/fr.json",
      ...
    }
  }
}
```

Each locale JSON file:
```json
{
  "NSUserTrackingUsageDescription": "Erlaube Booly, deine Werbe-ID zu verwenden...",
  "NSMicrophoneUsageDescription": "...",
  ...
}
```

**Evidence to check:**
- If tracking is used, check for `expo.locales` (top-level) in `app.json`.
- If `ios.locales` is present instead → **RISK** (Expo's `withLocales` plugin won't read it; relocate to top-level).
- If `CFBundleLocalizations: ["en"]` is the only locale declaration → **RISK** (this controls in-app strings but NOT the ATT system prompt language; use `expo.locales` for permission strings).

### 5.5 App Store Connect — Tracking Declaration

In **App Store Connect → App Privacy**, you MUST declare:
- "Do you or your third-party partners collect data from this app?" → **Yes**
- Under Data Types: **Advertising Data** → check "Used for Tracking"

If this isn't declared, Apple will reject even if the code is correct.

## 6. Privacy & Compliance (General)

- **Privacy Manifest (`PrivacyInfo.xcprivacy`)** — required by Apple since May 2024 for apps using "required reason APIs" (UserDefaults, file timestamp, disk space, system boot time, active keyboards). In Expo: `expo.ios.privacyManifests.NSPrivacyAccessedAPITypes`. In native: `PrivacyInfo.xcprivacy` in app target.
  - Each API must have a valid reason code (e.g. `CA92.1` for UserDefaults).
- **`NSPrivacyTracking`** — boolean; must be `true` if the app does any cross-app tracking (then ATT prompt also required).
- **`NSPrivacyTrackingDomains`** — list of tracking endpoints if `NSPrivacyTracking` is true.
- **`NSPrivacyCollectedDataTypes`** — declared data types match the App Store Connect Privacy Nutrition Label.
- **Privacy policy URL** — required for any app collecting user data, **mandatory** for HealthKit. Must be a public URL accessible without login. Must be entered in App Store Connect; ideally also linked from the in-app settings.
- **Terms of Service URL** — required if app has accounts, subscriptions, or UGC.

## 7. Account & Data Management

- **Account creation** — if account creation exists, **account deletion must exist in-app** (Guideline 5.1.1(v), enforced since June 30 2022).
  - Verify the delete button actually calls a delete endpoint (not just sign-out).
  - Must delete server-side data, not just local.
  - Must be reachable in ≤ a few taps from the main screen.
- **Email verification** — if claimed in the app or required for sensitive features, verify it's actually wired (not stubbed with `console.log`).
- **Password reset** — functional flow exists.
- **Sign-out** — exists and clears credentials.
- **Data export** — required in some jurisdictions (GDPR/CCPA); recommended.

## 8. Sign-In with Apple Parity (Guideline 4.8)

If the app offers **any** social login (Google, Facebook, Microsoft, Twitter/X, LINE, etc.), it MUST also offer Sign in with Apple, **equally prominent**, on the same screen. Check the sign-in screen component, not just `package.json`.

Exempt: education, enterprise, business apps using a company-specific login system; apps using only their own account system.

## 9. Network & Security

- **App Transport Security** — `NSAppTransportSecurity` should NOT contain `NSAllowsArbitraryLoads: true` without justification. Per-domain exceptions OK with reason.
- **HTTPS only** for all backend calls — grep for `http://` in source (excluding localhost dev).
- **No hardcoded secrets / API keys** in the bundle — grep for typical patterns (`sk_live`, `AKIA`, `AIza`, JWT-shaped strings) in source and `.env*` files committed to git.
- **`.env`, `.p8`, `.p12`, `*.keystore`** — must be in `.gitignore`. Verify with `git check-ignore`.

## 10. Encryption Export Compliance

- **`ITSAppUsesNonExemptEncryption`** — must be set in `Info.plist` (or `expo.ios.infoPlist`) to avoid being asked on every TestFlight upload.
  - `false` if app only uses standard HTTPS / iOS-provided crypto.
  - `true` if using non-exempt custom crypto, then submit annual self-classification report.

## 11. Background Modes

- `UIBackgroundModes` declared **only** for capabilities actually used (audio, location, fetch, processing, etc.). Apple rejects unjustified entries.
- For background location, must justify in the review notes.
- For background audio, app must actually play audio in background.

## 12. Deprecated / Risky SDKs

- **`expo-av`** — deprecated; use `expo-audio` / `expo-video`.
- **`react-native-async-storage`** older versions — needs Privacy Manifest entry (CA92.1).
- **`react-native-firebase`** — verify version supports Privacy Manifest.
- **WebView with arbitrary URLs** — security review.
- **`react-native-iap` vs StoreKit 2** — use a current StoreKit 2 wrapper.
- Any SDK known to fingerprint without disclosure.

## 13. In-App Purchases & Payments (if applicable)

- Digital goods/subscriptions MUST use StoreKit / Apple IAP — third-party payment processors (Stripe, etc.) are forbidden for digital content.
- Physical goods/services MAY use external processors.
- "Reader" apps may link out (Guideline 3.1.3(a)) with entitlement.
- Subscription terms shown clearly before purchase.
- Restore purchases button present.

## 14. Content & UX

- **No private API usage** — grep for known private symbols if app accesses low-level APIs.
- **No placeholder content** ("Lorem ipsum", "TODO", "FIXME" visible to user).
- **No mention of beta/test/debug** in user-facing copy on production builds.
- **No links to other platforms' stores** (e.g. "Download our Android app").
- **Crash-free on launch** — covered by TestFlight, but verify no obvious init crashes.
- **Demo account credentials** for reviewer if app has login (provided in App Store Connect, not the app).

## 15. Build & Distribution Hygiene

- **`eas.json` / build config** uses production scheme and signing.
- **No `console.log` in production builds** of sensitive data — review build minification.
- **Source maps** uploaded to crash reporter (Sentry, Bugsnag) but not shipped.
- **`expo-updates`** — if used, `runtimeVersion` policy is set; otherwise omit.

## 16. App Store Connect (out-of-repo)

These cannot be detected in source — flag them as required actions:

- App listing: name, subtitle, keywords, description, screenshots (6.7"/6.5"/5.5"/iPad), preview video.
- Age rating questionnaire complete.
- Privacy Nutrition Label complete and matching `NSPrivacyCollectedDataTypes`.
- Privacy policy URL filled in.
- Support URL filled in.
- Demo account provided to reviewer if login required.
- Export compliance answered.
- Content rights / third-party content declarations.
- App review information / contact / notes (especially for HealthKit, location-always, etc.).
- TestFlight beta complete with no critical crashes.

---

## How to grep efficiently

```bash
# Find all NS*UsageDescription keys actually declared
rg -n 'NS\w+UsageDescription' app.json ios/

# Find all permission/entitlement usage in code
rg -n 'expo-camera|expo-location|expo-notifications|HealthKit|CBCentralManager' --type ts --type tsx --type swift

# Check for explicit ATT request (CRITICAL for tracking apps)
rg -n 'requestTrackingPermissionsAsync|requestTrackingAuthorization' --type ts --type tsx --type swift

# Verify ATT timing (should be AFTER splash hide, not during module-load)
rg -n -B5 -A5 'requestTrackingPermissionsAsync' --type ts --type tsx

# Check for AdMob / tracking SDKs that require ATT
rg -n 'react-native-google-mobile-ads|@react-native-firebase/analytics|amplitude|mixpanel' package.json

# Check for locales config (must be top-level expo.locales, not ios.locales)
rg -n '"locales"' app.json

# Verify .env not tracked
git ls-files --error-unmatch .env apps/*/.env 2>&1

# Check for hardcoded secrets
rg -n 'sk_live_|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}'

# Check for HTTP (not HTTPS) endpoints
rg -n 'http://(?!localhost|127\.0\.0\.1)' --type ts
```
