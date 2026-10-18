# CONE TypeScript Admin Dashboard

React + TypeScript + Vite frontend, Express + TypeScript API, Firebase Authentication, and Cloud Firestore. Image bytes stay on the local VPS filesystem. This project lives independently from the Flutter application and preserves its `people`, `conference/main`, `couponIndex`, and `mealRedemptions` data contracts.

## Local setup

1. Install Node.js 20.19+ (Node 22 LTS recommended).
2. From this directory, run `npm install`.
3. Copy `.env.example` to `.env`. Use a separate Firebase development project first. Set both server project ID and Firebase **web app** configuration; do not use the Android app ID as the web app ID.
4. Provide Firebase Admin Application Default Credentials, or set `GOOGLE_APPLICATION_CREDENTIALS` to a private service-account JSON file outside the repository. The server account needs appropriate Firestore and Auth permissions.
5. Enable Email/Password sign-in in Firebase Authentication for dashboard accounts. Existing mobile email-link sign-in can remain enabled. Add `localhost` to authorized domains.
6. Create your first dashboard account in Firebase Authentication, set a password, and verify its email through Firebase's verification workflow. Do not mark unverified public users as verified to bypass authentication.
7. Bootstrap Super Admin access using that account's email:

   ```powershell
   npm run bootstrap -- admin@example.org "Your Full Name" "9876543210"
   ```

8. Super Admin MFA is required by default. Enable SMS MFA in Firebase Identity Platform. If the initial verified sign-in is rejected for a missing second factor, use the dashboard's SMS enrollment form and sign in again. For a local development project only, explicitly set `REQUIRE_ADMIN_MFA=false` if MFA is unavailable. Production startup rejects that bypass.
9. Run `npm run dev`. Open **http://localhost:3000**. The API listens on **http://127.0.0.1:8080**. No production data is seeded automatically.

The unconfigured UI shows setup instructions rather than fabricated live records. All management operations require a verified Firebase ID token and an active server-managed `adminUsers/{uid}` record. A conference `organiser` role alone never grants dashboard access.

## Implemented screens and operations

- Overview with live registrations, confirmed users, presenters, role breakdown, meals, and imports.
- Participant create/edit/search/pagination, required identity/affiliation validation, existing Flutter conference roles, status and fees.
- Super Admin account invitations, verification/password setup emails, access assignment, deactivation, token revocation, and self-demotion protection. Sensitive changes require a sign-in within the last five minutes.
- Programme sessions with venue overlap checking and publication to `conference/main.schedule`.
- Disciplines, venues, staff duties, VIP host assignments, fee records, and papers/authors. Papers and staff details publish into compatible participant objects.
- Meal slot configuration, coupon issuance to confirmed participants, and trusted single-use redemption with time-window checks.
- Signed pass issuance/reissue, revocation, and entry verification. Set `PASS_SIGNING_SECRET` to at least 32 random characters. Reissue invalidates the previous managed pass.
- Private VPS image uploads/archive, MIME/size/dimension validation, metadata stripping, authenticated previews, and persistent metadata.
- Excel sheet inspection, custom column mappings, participant template, USSTC headers, create/update modes, validation previews, downloadable row reports, job history, duplicate detection, and resumable failed imports with row idempotency.
- SMTP tests, saved plain-text templates, registered-recipient notification batches, persistent delivery jobs, and a separate retrying email worker. The Super Admin can configure SMTP in the panel; saved passwords are encrypted with AES-256-GCM using a server-only `CONFIG_ENCRYPTION_KEY`. Environment settings remain the fallback until an override is saved.
- Conference dates, venue/contact details, draft/published metadata, application feature settings, audit history, trusted analysis results, live backend health checks, and participant Excel exports.
- `npm run analyze` executes fixed build/test commands in trusted operations tooling and writes bounded, versioned analysis summaries to Firestore.
- Responsive desktop/mobile interface with separate software permissions and conference participation roles.

## Scope and remaining specification work

The local implementation covers the principal dashboard modules. The following boundaries need to be considered when integrating it with the existing app:

- One active event (`main`) is supported. Multi-conference management requires a Flutter/data migration.
- Dashboard authentication uses password + SMS MFA; the Flutter app retains Firebase email-link sign-in. Other MFA methods and administrative passwordless links are not included.
- Import validates every row before publication, then commits each participant transaction separately. A later server failure preserves successful rows; retry skips already-processed rows. It is not a transaction over the entire workbook. Existing email/role relationship migrations are intentionally restricted. Paper/author import and automated multi-author identity disambiguation are not included; manage papers in their own screen. Participant Auth accounts can be created by Firebase's existing email-link flow; dashboard account invitations explicitly create Auth accounts.
- Workbook intake limits compressed files, ZIP entries, expanded bytes, sheets, rows, macros, and external workbook links. Imports are restricted to authorized staff, not a public upload endpoint. Import execution runs in the API process; failed jobs can be retried. A server interruption leaves a ten-minute lease before recovery; automatic scheduling/recovery of imports is not included.
- Email delivery is at least once: stable message IDs and batch idempotency reduce duplicates, but SMTP cannot guarantee exactly-once delivery if the process fails after the server accepts a message and before status is persisted. Up to five attempts use backoff. Run the worker separately; queuing alone does not send messages.
- Fees are administrative whole-INR records, not a payment-gateway integration or accounting ledger. Participant exports are capped at 5,000 records per request.
- Discipline records are stored administratively; official workbook summary totals are not overwritten with live registration counts.
- Newly issued signed pass strings are compatible with the mobile QR payload field. The entry panel accepts pasted/scanned token text; a built-in camera scanner and rotating/expiring tokens are not included. Legacy plain-ID passes need reissue before signed verification can accept them. The mobile UI must refresh after issuance and does not yet display revoked status itself.
- Media is private; device-only selfies stay on the device. Public branding delivery, replacement versioning, retention cleanup, and automated backup/restore tooling are not included. VPS backups remain an operator responsibility.
- Analysis publication is available through `npm run analyze`; CI credentials, scheduling, and release deployment must be configured for your infrastructure.
- Archive is available for standalone records and participants/accounts. Linked paper/staff relationship migrations and participant email changes require a reviewed migration to avoid orphaned mobile data.
- Maintenance mode is enforced by this dashboard API for non-Super-Admin accounts. Registration-open and publication status are stored metadata for subsequent public/mobile integration; they do not currently gate the Flutter app. Conference data is cached in the current Flutter repository, so users may need to restart it to see new programme data.
- The existing root Firestore rules are unchanged and must be hardened/reviewed before production, especially the legacy direct-client redemption flow. Never assume server checks protect direct mobile writes. See the proposed rule file in `firebase/`.

## Firebase data and security

Administrative collections are accessed exclusively through the API using Firebase Admin SDK. **Admin SDK bypasses Firestore rules**, so the API checks account state, verified identity, permissions, and scope on every request. Do not add broad browser write permissions for admin collections.

`adminUsers/{uid}` stores `fullName`, `email`, `mobile`, `accessRole`, `conferenceId: "main"`, `status`, and a concurrency version. Super Admin is a software access role; it is deliberately absent from the Flutter `Role` enum.

The supplied `firebase/firestore.rules` is a proposed replacement for the root rules, not automatically deployed. It retains mobile reads, restricts new administrative collections, and strengthens coupon checks. Review and emulator-test it with the Flutter app before deploying it. Existing coupon-index data lacks new slot links and will need migration to use the stricter redemption rules.

## Commands

```powershell
npm run dev       # frontend + API
npm test          # validation and permission tests
npm run test:browser # mocked Firebase/API browser journey; Edge on Windows
npm run build    # strict TypeScript, frontend, and server builds
npm start        # compiled server + static frontend
npm run worker   # development email delivery worker (separate terminal)
npm run worker:production # compiled worker under a separate supervisor
npm run analyze  # run checks and publish trusted reports; needs Firebase credentials
```

## VPS deployment

1. Provision the supported Node runtime and install with `npm ci`. Run `npm run build`.
2. Set `APP_ENV=production`, HTTPS `ADMIN_BASE_URL`, exact `CORS_ALLOWED_ORIGINS`, Firebase web/server configuration, `REQUIRE_ADMIN_MFA=true`, persistent `STORAGE_ROOT=/srv/cone/storage`, and TLS SMTP settings.
3. Keep `VITE_API_BASE_URL=/api` for a same-origin reverse proxy. Public `VITE_*` settings are built into the browser bundle, so rebuild after changing them. Secrets must never use `VITE_*` names.
4. Run `npm start` under a process supervisor with the project as its working directory. Proxy HTTPS traffic to `127.0.0.1:8080`; the server serves the compiled web app as well as the API. Forward bearer headers. Do not expose `STORAGE_ROOT` as a public directory.
   Run `npm run worker:production` under a second supervisor to deliver queued invitations and notifications. Configure `PASS_SIGNING_SECRET` before issuing signed passes; retain the secret securely across restarts.
   Set `CONFIG_ENCRYPTION_KEY` to a base64-encoded random 32-byte key before saving SMTP passwords through the panel. Generate it with `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"`. Keep the key outside the database and retain it with secure recovery material; changing it makes existing encrypted credentials unreadable.
5. Back up Firestore and the VPS storage together, restrict file permissions, and configure monitoring and log retention. Do not run the application as root.
6. Complete the remaining scope above and run real Firebase/rules/SMTP integration checks before public production use.

Development uses relative API URLs. VPS images are requested through authenticated `/api/media/{assetId}/file` endpoints; database asset metadata stores only relative storage keys. On physical mobile devices, use a reachable LAN hostname rather than `localhost`.

## Verification

Local checks cover strict compilation, validation and permissions, HTTP authorization boundaries with mocked Firebase Admin, real XLSX encoding/decoding and limits, and a desktop/mobile browser journey using intercepted Firebase/API responses. Browser fixtures never write to a Firebase project. On non-Windows hosts, install Playwright Chromium with `npx playwright install chromium` before the browser check.

Live Firebase login/data writes, SMS enrollment/delivery, Firestore rule behavior, SMTP delivery, and VPS deployment require your credentials and infrastructure and have not been verified by these local checks. No production Firebase resources or existing root rules are changed automatically.

Dependency overrides pin compatible Firebase app packages for Node 20 and patch transitive gRPC/UUID advisories. The lockfile records the tested dependency graph; use `npm ci` to reproduce it.

## Source references

- [Dashboard specification](../DASHBOARD_REQUIREMENTS.md)
- [Firebase ID-token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [Vite setup and runtime requirements](https://vite.dev/guide/)
