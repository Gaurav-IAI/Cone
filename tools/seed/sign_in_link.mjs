// Prints an email sign-in link for one of the seeded sample accounts, without
// sending an email. For testing on an emulator/device you control:
//
//   node sign_in_link.mjs gauravkumarsony08+speaker@gmail.com
//   adb shell am start -a android.intent.action.VIEW -d "<link>" com.usstc.usstc_conferenc
//
// Uses the same Application Default Credentials as seed.mjs. Refuses any
// email that is not in seed_data.json.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const here = dirname(fileURLToPath(import.meta.url));
const data = JSON.parse(readFileSync(join(here, 'seed_data.json'), 'utf8'));
const email = (process.argv[2] ?? '').trim().toLowerCase();
if (!data.people.some((p) => p.email === email)) {
  console.error('Usage: node sign_in_link.mjs <sample account email>');
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: 'conferencemanagement-239a3' });
const link = await getAuth().generateSignInWithEmailLink(email, {
  url: 'https://conferencemanagement-239a3.firebaseapp.com/finishSignIn',
  handleCodeInApp: true,
  android: { packageName: 'com.usstc.usstc_conferenc', installApp: false, minimumVersion: '1' },
});
console.log(link);
