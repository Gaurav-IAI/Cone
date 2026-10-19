# CONE — Conference Operations & Networking Environment

> **Current login (no passwords):** everyone enters their registered name, email
> and mobile and taps Continue.
> - The six fictional demo accounts go straight in, with no email.
> - Every other registration is emailed a six-digit code to its registered
>   address; entering it opens their screen. This needs the dashboard API
>   running with `OTP_AUTH_ENABLED=true` and `OTP_HMAC_SECRET` (see
>   `admin-dashboard/.env.otp.example`), working SMTP, and Firebase custom-token
>   signing (IAM Service Account Credentials API enabled, or a service-account
>   key in `GOOGLE_APPLICATION_CREDENTIALS`).
>
> Build: `flutter build apk --release --dart-define=AUTH_API_URL=https://YOUR-API-HOST`
> from the Flutter project root. Release APKs need an HTTPS API address the
> phone can reach (a VPS, or a tunnel to `localhost:8080`).
> First-time setup/refresh: `node tools/seed/setup_direct_demo_login.mjs` with ADC.
> The generated `assets/testing/demo_login.json` is ignored by Git and contains
> credentials only for the six fictional demo accounts, never admin credentials.
> These demo credentials are bundled into the testing APK and are extractable;
> this is deliberately a demo-only build. Disable it with
> `--dart-define=DIRECT_DEMO_LOGIN=false` before restoring other login modes.
> Previous API/verification setup sections below describe retained alternatives
> and are not required for the current direct-login testing flow.


A Flutter participant companion app for the *21st Uttarakhand State Science & Technology Congress 2026-27*. A registered participant signs in with an emailed link, takes a selfie that stays on the device, and views a read-only dashboard with scannable meal coupons. Volunteers scan and serve coupons.

> Six fictional sample people (one per role) live in Firebase, loaded from `tools/seed/seed_data.json`. Sign-in is real Firebase email-link sign-in; meal coupons are redeemed in Cloud Firestore. The QR **pass** is not yet connected to any entry system.

## TypeScript admin dashboard

The separate [`admin-dashboard/`](admin-dashboard/README.md) project implements the web administration interface with React, TypeScript, an Express API, Firebase Authentication, and Firestore. See its README for local setup, Super Admin bootstrap, SMTP worker, VPS storage, verification, and integration boundaries. Requirements are in [`DASHBOARD_REQUIREMENTS.md`](DASHBOARD_REQUIREMENTS.md).

## Flow

Everyone signs in the same way: **name + email + mobile → emailed sign-in link → selfie → dashboard**. The name and mobile must match the registration in Firestore. The selfie is saved only on the phone (app-private storage) and is removed on sign-out; a stored selfie skips the selfie step next time.

The dashboard and the screen **background colour** depend on the role:

| Role | Background | Extra on the dashboard |
|---|---|---|
| Presenter | teal | Your abstract, Paper & authors, "Your presentation" in the schedule |
| Attendee | blue | — (pass, coupons, schedule) |
| Speaker | purple | Your talk (title, session, time, venue, summary) |
| VIP | gold | Your host (organiser contact), VIP programme items |
| Organiser | green | Overview (registrations per role, meals served), People directory, Meal desk, duties |
| Volunteer | orange | Meal desk (scan coupon → *Done — mark as served*), duties |

Every role has a QR pass (encodes only the pass ID) and six meal coupons (breakfast, lunch, dinner × 2 days), each with its own QR. A served coupon turns **Used** on the owner's phone immediately; scanning it again shows **Already used**.

## Sample accounts

All are fictional people. These role-based addresses are testing identifiers; the in-app testing flow does not send email.

| Role | Name | Email | Mobile |
|---|---|---|---|
| Presenter | Aarav Mehra | presenter@gmail.com | 9876543210 |
| Attendee | Riya Bhandari | attendee@gmail.com | 9876543211 |
| Speaker | Prof. Nandini Rautela | speaker@gmail.com | 9876543212 |
| VIP | Dr. Vinod Tamta | vip@gmail.com | 9876543213 |
| Organiser | Dr. Kavita Negi | organizer@gmail.com | 9876543214 |
| Volunteer | Rohit Bisht | volunteer@gmail.com | 9876543215 |

## Data — `tools/seed/seed_data.json`

The single source loaded into Firebase by `tools/seed/seed.mjs`. Conference facts (title, 13 disciplines, totals, category and O/P codes) come from the MAIN sheet of `USSTC 21 Final116 (1).xlsx` (unchanged); the presenter follows the workbook's column structure. Everything else (people, schedule, coupons, IDs) is sample data, flagged `isDemo: true`. No real participant is included.

## Firebase

Project `conferencemanagement-239a3`, Android app `com.usstc.usstc_conferenc`.

| Collection | Contents | Who can read |
|---|---|---|
| `conference/main` | title, disciplines, totals, shared schedule | anyone |
| `people/{email}` | one registration per person, with `role` | the person; organisers |
| `couponIndex/{couponId}` | coupon → owner, for the meal desk | volunteers, organisers |
| `mealRedemptions/{couponId}` | created once when a meal is served; never changed | owner (own coupons), volunteers, organisers |

Rules: `firestore.rules`. The app never writes `people`, `conference` or `couponIndex`.

### Loading the data

```bash
gcloud auth application-default login      # once, as the project owner
cd tools/seed && npm install
node seed.mjs --dry-run                     # list what would be written
node seed.mjs                               # Firestore + Auth users (idempotent)
cd ../.. && firebase deploy --only firestore:rules
```

To test a sample account on an emulator without waiting for the email, `node tools/seed/sign_in_link.mjs <sample email>` prints a sign-in link (Admin SDK; refuses emails not in the seed file); open it with `adb shell am start -a android.intent.action.VIEW -d "<link>" com.usstc.usstc_conferenc`.

Play Store screenshots: see [store_assets/screenshots/README.md](store_assets/screenshots/README.md).

### One-time project setup

1. **Authentication → Sign-in method:** *Email/Password* with *Email link (passwordless sign-in)* enabled.
2. **Project settings → Android app:** add signing fingerprints (debug key on this PC: SHA-1 `AA:44:BA:22:2A:8C:F3:E6:DF:9F:F2:36:9A:97:06:D8:C7:7D:E1:21`, SHA-256 `E2:CC:26:3F:88:47:E7:74:E4:2E:E4:88:76:BD:F5:DC:57:6B:87:C9:BD:FF:CD:8C:D8:5F:9C:DB:AC:AE:AD:3F`). For Play, add the Play app-signing SHA-256 too, also in `hosting/public/.well-known/assetlinks.json`.
3. **Optional:** `firebase deploy --only hosting` so email links open the app directly.

## Commands

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug          # -> build/app/outputs/flutter-apk/app-debug.apk
flutter run                        # with a phone connected (USB debugging on)
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Built with Flutter 3.41.6 / Dart 3.11.4. `permission_handler` is pinned to `^12.0.1`: version 13 pulls in `permission_handler_android` 14, which needs Android Gradle Plugin 9 and compileSdk 37.

**iOS:** not built (needs a Mac). Before the first iOS build, add `PERMISSION_CAMERA=1` to `GCC_PREPROCESSOR_DEFINITIONS` in the generated `ios/Podfile` (see the permission_handler README). The camera usage text is already in `Info.plist`.

## Code layout

```
lib/
  main.dart                     app wiring (swap the auth service here)
  app/                          theme, in-memory session, AppScope
  auth/participant_auth_service.dart   interface the screens use
  auth/firebase_auth_service.dart      Firebase email-link implementation
  data/firestore_repository.dart       reads conference, people, coupons
  coupons/                             coupon status + Firestore redemption
  app/roles.dart                       per-role label, icon and colours
  app/selfie_store.dart                selfie kept in app-private storage
  auth/identity_matcher.dart           name/email/mobile normalisation
  data/models.dart              typed, validated JSON models
  data/demo_data_repository.dart       loads the bundled JSON
  screens/                      one file per screen
  widgets/common.dart           shared UI pieces
test/                           data, auth and full-journey widget tests
```

## Before any public release

This build is fine for screenshots and a closed/internal test track. It is **not** ready to publish to real participants.

1. **Real registrations.** Only sample people are loaded. Real records (from the workbook, with consent and correct emails) must be imported with the same structure, and coupon IDs issued for each.
2. **Sign-in links can be requested for any email** (Firebase rate-limits them); registration is checked after the link is opened.
3. **Selfie.** It currently has no purpose beyond the demo. If it is used for identity checks or badges, you need a stated purpose, consent, retention rules, and secure upload/storage. No face matching or liveness check exists.
4. **QR pass.** It needs a server-issued, signed or rotating token and an entry scanner that validates it.
5. **Food coupons.** Redemption works (Firestore, single use). Meal times are sample values until the organisers confirm them.
6. **Play Store.** Upload keystore and release signing (release currently uses debug keys), a privacy policy, Data safety form (camera; personal data once real), camera permission disclosure, an organiser-owned application ID if required, target-SDK review, and confirmed official conference details (dates, venue, organiser).

Store assets: `store_assets/play_icon_512.png` (full logo, 512×512) for the Play listing icon. The Play app name is limited to 30 characters, so use e.g. "CONE – USSTC Companion" as the title and put "Conference Operations & Networking Environment" in the short description.
### In-app email verification testing

The mobile app defaults to in-app testing verification. No email is sent in this
mode, including when configuration is missing. The existing app signs in existing
registrations; it does not create conference registrations.

1. In the admin API environment, set `TEST_IN_APP_EMAIL_VERIFICATION=true` with a
   non-production `APP_ENV`, and start the API using its existing Firebase Admin
   credentials. Keep this testing server private.
2. In `tools/seed`, run `node seed.mjs --verification-test-data --enable-email-link`
   to populate the twelve test registrations and initially unverified Auth users.
   Preview writes with `node seed.mjs --verification-test-data --dry-run`.
3. Run the mobile app with
   `flutter run --dart-define=TEST_VERIFICATION_API_URL=https://YOUR-TEST-API`.
   Use a device-reachable HTTPS address without a trailing slash or `/api`.
4. Enter the fixture's name, email and mobile, continue, then tap **Verify Email**.
   The app displays a genuine Firebase link and consumes it internally. Firebase
   verifies the Auth identity, and the API updates `people/{email}` with
   `emailVerified: true` and `emailVerificationStatus: Verified`.

Test accounts are in `tools/seed/verification_test_data.json`: three each of
`participant1@participant.com`, `attendee1@attendee.com`,
`volunteer1@volunteer.com`, and `organizer1@organizer.com` (numbers 1�3).
Names follow `Test Participant 1` and the corresponding role/number. Exact mobile
numbers and unique pass/coupon IDs are in the fixture. Participant uses the
existing `presenter` role; Organizer uses `organiser`. Ordinary demo data remains
separate. Re-seeding the test fixture resets verification to Pending.

Restore email delivery with `--dart-define=IN_APP_EMAIL_VERIFICATION=false` and
unset the server testing flag. The testing endpoint refuses production mode.
Firestore rules and other email features remain unchanged. This flow intentionally
substitutes registration details for proof of inbox ownership during testing.

### Updating existing sample-account emails

The six sample accounts now use `presenter@gmail.com`, `attendee@gmail.com`,
`speaker@gmail.com`, `vip@gmail.com`, `organizer@gmail.com`, and
`volunteer@gmail.com`; names and mobile numbers in the table above are unchanged.
The live Firebase migration was applied and verified. Existing Auth UIDs,
registration/pass/coupon IDs and non-email record fields were preserved, and
coupon-owner email references were updated.

For another database with the original accounts, preview with
`node tools/seed/migrate_role_emails.mjs`, then apply with `--apply`. The migration
checks for destination conflicts, creates a local recovery snapshot, updates
existing Auth users, and transactionally moves the email-keyed Firestore records.
It does not create users or send email. Prefer this migration over re-seeding
existing accounts. The original addresses remain only in its migration mapping.

`node tools/seed/verify_role_logins.mjs` checks real Firebase email-link sign-in
and authenticated Firestore access for all six sample accounts. It generates and
consumes links internally without mail delivery and does not print session tokens.


### Temporary automatic Continue (current testing flow)

`AUTO_VERIFY_EMAIL=true` is the default while in-app testing authentication is
active. Continue validates the existing name/email/mobile record, automatically
sets Firebase Auth and database email status to Verified, signs in with a Firebase
custom token, and opens the existing selfie/dashboard step. No links or OTPs are
generated or sent, and the verification screen is skipped for all roles.

The API still requires `APP_ENV=test` (or `development`) and
`TEST_IN_APP_EMAIL_VERIFICATION=true`. Custom-token sign-in requires a signing
service-account credential; user ADC additionally needs an explicit
`FIREBASE_SERVICE_ACCOUNT_ID` and existing `iam.serviceAccounts.signBlob`
permission on that account. No signing credentials belong in the APK.

Build against a configured testing API:
`flutter build apk --release --dart-define=TEST_VERIFICATION_API_URL=https://YOUR-TEST-API`.

The old screen and email-link code remain intact but are bypassed. Restore the
manual in-app Verify Email screen with `--dart-define=AUTO_VERIFY_EMAIL=false`.
Restore original inbox-based sign-in with
`--dart-define=IN_APP_EMAIL_VERIFICATION=false` and disable the server testing flag.
