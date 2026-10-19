// Loads tools/seed/seed_data.json into Firebase project conferencemanagement-239a3.
//
//   node seed.mjs                 Firestore + Auth users
//   node seed.mjs --enable-email-link   also turns on Email link sign-in
//   node seed.mjs --dry-run       print what would be written
//
// Credentials: Application Default Credentials, e.g. after
//   gcloud auth application-default login
// Writes only these documents (overwriting earlier seed runs):
//   conference/main, people/{email}, couponIndex/{couponId}
// It never deletes anything and never touches mealRedemptions.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

const PROJECT_ID = 'conferencemanagement-239a3';
const here = dirname(fileURLToPath(import.meta.url));
const data = JSON.parse(readFileSync(join(here, process.argv.includes('--verification-test-data') ? 'verification_test_data.json' : 'seed_data.json'), 'utf8'));
const args = new Set(process.argv.slice(2));
const dryRun = args.has('--dry-run');

const roleLabel = {
  presenter: 'Presenter', attendee: 'Attendee', speaker: 'Speaker',
  vip: 'VIP', organiser: 'Organiser', volunteer: 'Volunteer',
};

function plan() {
  const writes = [['conference/main', data.conference]];
  for (const p of data.people) {
    writes.push([`people/${p.email}`, p]);
    for (const c of p.coupons) {
      writes.push([`couponIndex/${c.couponId}`, {
        couponId: c.couponId, day: c.day, meal: c.meal, window: c.window,
        email: p.email, fullName: p.fullName,
        registrationId: p.registrationId, role: p.role,
      }]);
    }
  }
  return writes;
}

async function seedFirestore(db, writes) {
  const batch = db.batch();
  for (const [path, doc] of writes) {
    batch.set(db.doc(path), { ...doc, seededAt: FieldValue.serverTimestamp() });
  }
  await batch.commit();
}

// An earlier `firebase auth:import` (uid prefix "cone") duplicated an email
// that already had an account. Remove only such never-used duplicates.
async function removeImportedDuplicates(auth) {
  const wanted = new Set(data.people.map((p) => p.email));
  const byEmail = new Map();
  let page;
  do {
    page = await auth.listUsers(1000, page?.pageToken);
    for (const u of page.users) {
      if (!u.email || !wanted.has(u.email.toLowerCase())) continue;
      const list = byEmail.get(u.email.toLowerCase()) ?? [];
      list.push(u);
      byEmail.set(u.email.toLowerCase(), list);
    }
  } while (page.pageToken);
  for (const [email, users] of byEmail) {
    if (users.length < 2) continue;
    for (const u of users) {
      if (u.uid.startsWith('cone') && !u.metadata.lastSignInTime) {
        await auth.deleteUser(u.uid);
        console.log(`  auth  removed duplicate ${u.uid} for ${email}`);
      }
    }
  }
}

async function seedAuth(auth) {
  await removeImportedDuplicates(auth);
  for (const p of data.people) {
    const fields = { displayName: p.fullName, emailVerified: p.emailVerified ?? true };
    try {
      const user = await auth.getUserByEmail(p.email);
      await auth.updateUser(user.uid, fields);
      console.log(`  auth  updated ${p.email} (${roleLabel[p.role]})`);
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
      await auth.createUser({ email: p.email, ...fields });
      console.log(`  auth  created ${p.email} (${roleLabel[p.role]})`);
    }
  }
}

async function enableEmailLink(credential) {
  const { access_token: token } = await credential.getAccessToken();
  const url = `https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/config`
    + '?updateMask=signIn.email.enabled,signIn.email.passwordRequired';
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'X-Goog-User-Project': PROJECT_ID,
    },
    body: JSON.stringify({ signIn: { email: { enabled: true, passwordRequired: false } } }),
  });
  if (!res.ok) throw new Error(`Enable email link failed: ${res.status} ${await res.text()}`);
  console.log('  auth  Email link (passwordless) sign-in enabled');
}

const writes = plan();
console.log(`${writes.length} Firestore documents, ${data.people.length} Auth users`);
if (dryRun) {
  for (const [path] of writes) console.log('  would write', path);
  process.exit(0);
}

const credential = applicationDefault();
initializeApp({ credential, projectId: PROJECT_ID });
if (args.has('--enable-email-link')) await enableEmailLink(credential);
await seedFirestore(getFirestore(), writes);
console.log(`  firestore  wrote ${writes.length} documents`);
await seedAuth(getAuth());
console.log('Done.');
