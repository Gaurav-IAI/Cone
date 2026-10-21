# Conference roles: data and sign-in

Every person is one Firestore document, `people/{email}` (lower-case email),
plus a passwordless Firebase Auth account with the same email. The mobile app
holds no credentials for real people: it signs in with an emailed OTP checked by
the API, then reads the person's own `people/{email}` document. The role in that
document decides which dashboard, colour and data the app shows.

A registration with `accountType: "test"` skips OTP: `POST /api/auth/test-login`
checks the name, email and mobile and returns the session token directly. A
Super Admin turns this on or off per person in the dashboard (Participants →
Edit → "Test account"), and the API's `ALLOW_TEST_ACCOUNT_LOGIN=false` turns it
off for everyone. The six fixed demo accounts (`isDemo: true`) are marked this
way. Every other registration must use OTP.

## Sign-in flow (mobile)

1. The user enters full name, email and mobile number and taps **Continue**.
2. `POST /api/auth/email-otp/request` checks `people/{email}` and Firebase Auth:
   - The name and mobile must match the record. Case and spacing are ignored, and `+91` or a leading `0` is accepted.
   - The registration must not be cancelled, suspended or archived.
   - The Auth account must exist and must not be disabled.
   - Otherwise the request fails with **"User data not found in system"** and no email is sent.
3. A six-digit code goes to that email. It expires after 5 minutes, and a new code can be requested after 60 seconds.
4. `POST /api/auth/email-otp/verify` checks the code. If it's correct, the API marks the email as verified and returns a Firebase custom token.
5. The app signs in with that token, loads `people/{email}` and opens the selfie screen, then the role dashboard.

## Fields every role has

| Field | Notes |
|---|---|
| `fullName`, `email`, `mobile` | Identity checked at login. `mobile` is 10 digits and starts with 6–9. |
| `role` | `presenter`, `attendee`, `speaker`, `vip`, `organiser` or `volunteer` |
| `registrationStatus` | `confirmed` is needed for meal coupons. `cancelled` and `suspended` block login. |
| `registrationId`, `passId` | Generated once and never reused. `passId` is the only value in the QR pass. |
| `affiliation` | Institution |
| `designation`, `workingAs` | Optional display text |
| `personalSchedule[]` | `{day, start, end, title, venue, kind, isOwnPresentation}`, merged with `conference/main.schedule` |
| `coupons[]` | `{couponId, slotId, day, meal, window}`, one per active `mealSlots` document. Each coupon is mirrored in `couponIndex/{couponId}` with the owner's email, name, registration ID and role. |
| `isDemo` | `false` for real people |

## Role-specific data

| Role | Required data | What the app shows |
|---|---|---|
| **Presenter** | `paper {submissionId, title, abstractText, authors[]}`, `category` (I–IV), `presentationType` (`O` oral or `P` poster), `discipline`, and a schedule item for their own presentation. The paper is mirrored in `submissions/{submissionId}`. | Paper and abstract, presentation slot, pass, coupons |
| **Attendee** | Nothing beyond the common fields | Conference schedule, pass, coupons |
| **Speaker** | `talk {title, session, day, start, end, venue, abstract}` and schedule items for check-in and the talk | Talk details, personal schedule, pass, coupons |
| **VIP** | `host {name, role, mobile}`, taken from the organiser or volunteer assigned to them, and a schedule of their engagements | Host contact, engagement schedule, pass, coupons |
| **Organiser** | `duties[]` and duty schedule items | Duties, overview, people list, meal desk (scan and redeem coupons) |
| **Volunteer** | `duties[]` and duty schedule items | Duties, meal desk (scan and redeem coupons) |

When a role changes, the old role's data (paper, talk, host, duties) is removed so it isn't shown under the new role.

## Firestore access (`firestore.rules`)

- Each person can read only their own `people/{email}` document, and only with a verified email (OTP verification sets this).
- Organisers can read and list all `people` documents.
- Organisers and volunteers can look up `couponIndex` and record a meal once in `mealRedemptions`. Nobody can change a recorded meal afterwards.
- Only the API, which uses the Admin SDK, writes registrations.

## Adding or changing people

- **Dashboard:** use Participants, Submissions, Staff, Meals → Issue coupons.
- **In bulk from a file:** in the separate `cone-admin-dashboard` repository, put the people in a JSON file under `storage/`. That folder is ignored by Git, so personal data stays out of the repository. Then run:

  ```powershell
  cd ../cone-admin-dashboard
  npm run provision:people -- storage/test-people.json --dry-run   # preview
  npm run provision:people -- storage/test-people.json
  ```

  Each entry has the common fields above plus its role's data. A VIP names their host with `hostEmail`. The script:
  - is safe to re-run, and keeps existing IDs and coupons;
  - refuses to change demo or dashboard test identities;
  - confirms that each person passes the OTP eligibility check.
