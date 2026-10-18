# CONE — Google Play screenshots

Genuine captures of the CONE app (release candidate build, debug-signed) running against the live Firebase project with the **sample accounts** from `tools/seed/seed_data.json`. All people shown are fictional. Nothing was mocked up: every image is a straight screen capture, with only these edits:

- Phone images are cropped to 1080 × 2160 (status bar and gesture bar removed) because Play rejects images taller than 2:1.
- On every `05-personal-profile` image the email value is blurred, because the sample accounts use the developer's Gmail aliases.

## How they were captured

- Android emulator *Pixel 10* (Android 17, Google APIs), status bar in System UI demo mode (10:00, full battery).
- Phone: native 1080 × 2424 @ 420 dpi.
- 7-inch tablet: `wm size 1200x1920`, `wm density 320` (600 dp wide).
- 10-inch tablet: `wm size 1600x2560`, `wm density 320` (800 dp wide).
- Sign-in: the app's real Firebase email-link flow. Links were generated with `tools/seed/sign_in_link.mjs` (Admin SDK, sample accounts only) instead of being emailed.
- The camera permission was denied on the emulator, so profiles show initials and no camera image appears.
- The volunteer image stops at the **Valid** check; *Done — mark as served* was not tapped, so no production record was changed.

## Final images (upload these)

| # | Feature | Phone | 7-inch tablet | 10-inch tablet |
|---|---|---|---|---|
| 01 | Dashboard (Presenter) | `phone/01-conference-dashboard-phone.png` | `tablet_7_inch/01-conference-dashboard-tablet7.png` | `tablet_10_inch/01-conference-dashboard-tablet10.png` |
| 02 | Virtual conference pass (QR) | `phone/02-virtual-pass-phone.png` | `tablet_7_inch/02-virtual-pass-tablet7.png` | `tablet_10_inch/02-virtual-pass-tablet10.png` |
| 03 | Digital meal coupons | `phone/03-meal-coupons-phone.png` | `tablet_7_inch/03-meal-coupons-tablet7.png` | `tablet_10_inch/03-meal-coupons-tablet10.png` |
| 04 | Conference programme | `phone/04-conference-schedule-phone.png` | `tablet_7_inch/04-conference-schedule-tablet7.png` | `tablet_10_inch/04-conference-schedule-tablet10.png` |
| 05 | Personal profile | `phone/05-personal-profile-phone.png` | `tablet_7_inch/05-personal-profile-tablet7.png` | `tablet_10_inch/05-personal-profile-tablet10.png` |
| 06 | Speaker experience | `phone/06-speaker-experience-phone.png` | `tablet_7_inch/06-speaker-experience-tablet7.png` | `tablet_10_inch/06-speaker-experience-tablet10.png` |
| 07 | Organiser dashboard | `phone/07-organiser-dashboard-phone.png` | `tablet_7_inch/07-organiser-dashboard-tablet7.png` | `tablet_10_inch/07-organiser-dashboard-tablet10.png` |
| 08 | Volunteer meal desk | `phone/08-volunteer-meal-desk-phone.png` | `tablet_7_inch/08-volunteer-meal-desk-tablet7.png` | `tablet_10_inch/08-volunteer-meal-desk-tablet10.png` |

Sizes: phone 1080 × 2160, 7-inch 1200 × 1920, 10-inch 1600 × 2560. All PNG, all under 250 KB.

## Validation

`python store_assets/screenshots/validate.py` (from the project root) re-checks every final image — opens and decodes, PNG/JPEG, ≤ 8 MB, per-category dimension limits (phone and 7-inch 320–3,840 px; 10-inch 1,080–7,680 px), aspect ≤ 2:1, portrait, no duplicates — and writes `manifest.json`. Last run: 24/24 PASS.

## `source/`

Unedited captures. `source/phone/` also has extra screens (login, coupon QR, conference information, paper, speaker schedule, people list, VIP and attendee dashboards, volunteer dashboard and meal desk). **Do not upload** `source/` files: the `*-unredacted.png` and `05-presenter-my-details.png` captures show the real Gmail address, and the phone captures are taller than 2:1.

## Uploading in Play Console

1. Play Console → your app → **Grow users → Store presence → Main store listing**.
2. **Phone screenshots:** upload the 8 files from `phone/` in order 01–08.
3. **7-inch tablet screenshots:** upload the 8 files from `tablet_7_inch/`.
4. **10-inch tablet screenshots:** upload the 8 files from `tablet_10_inch/`.
5. Save. The app icon (`store_assets/play_icon_512.png`) and a 1024 × 500 feature graphic are uploaded on the same page; the feature graphic still has to be made.
