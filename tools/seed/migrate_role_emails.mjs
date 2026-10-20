// Run first without arguments to preview; --apply updates existing accounts only.
// Uses ADC against the application's Firebase project, never sends any email.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { isDeepStrictEqual } from 'node:util';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const mappings = [
  ['gauravkumarsony08@gmail.com', 'presenter@gmail.com', 'presenter'],
  ['gauravkumarsony08+attendee@gmail.com', 'attendee@gmail.com', 'attendee'],
  ['gauravkumarsony08+speaker@gmail.com', 'speaker@gmail.com', 'speaker'],
  ['gauravkumarsony08+vip@gmail.com', 'vip@gmail.com', 'vip'],
  ['gauravkumarsony08+organiser@gmail.com', 'organizer@gmail.com', 'organiser'],
  ['gauravkumarsony08+volunteer@gmail.com', 'volunteer@gmail.com', 'volunteer'],
];
if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST)
  throw new Error('This migration requires the actual application database.');
initializeApp({ credential: applicationDefault(), projectId: 'conferencemanagement-239a3' });
const db = getFirestore(), auth = getAuth();
const pairs = [];
async function findUser(email) {
  try { return await auth.getUserByEmail(email); }
  catch (e) { if (e.code === 'auth/user-not-found') return null; throw e; }
}
for (const [oldEmail, email, role] of mappings) {
  const [oldDoc, newDoc, oldUser, newUser] = await Promise.all([
    db.doc(`people/${oldEmail}`).get(), db.doc(`people/${email}`).get(),
    findUser(oldEmail), findUser(email),
  ]);
  if (!oldDoc.exists && newDoc.exists && !oldUser && newUser) {
    if (newDoc.data().role !== role) throw new Error(`Role mismatch for ${email}`);
    console.log(`${role}: already migrated (${newUser.uid})`); continue;
  }
  if (!oldDoc.exists || newDoc.exists || !oldUser || newUser)
    throw new Error(`Missing source or destination conflict for ${role}; no new users will be created.`);
  if (oldDoc.data().role !== role || oldDoc.data().email !== oldEmail)
    throw new Error(`Unexpected source registration for ${role}`);
  if ((await oldDoc.ref.listCollections()).length)
    throw new Error(`Source has subcollections; extend migration before moving ${role}`);
  pairs.push({ oldEmail, email, role, oldDoc, user: oldUser });
}
const replacements = new Map(pairs.map(p => [p.oldEmail, p.email]));
function replace(value) {
  if (typeof value === 'string') return replacements.get(value) ?? value;
  if (Array.isArray(value)) return value.map(replace);
  if (value && Object.getPrototypeOf(value) === Object.prototype)
    return Object.fromEntries(Object.entries(value).map(([k,v]) => [k,replace(v)]));
  return value; // Preserve Firestore timestamps, references, geopoints and bytes.
}
const moves = new Set(pairs.map(p => p.oldDoc.ref.path));
const associated = [];
async function scan(collection) {
  for (const snap of (await collection.get()).docs) {
    const data = snap.data(), updated = replace(data);
    if (!moves.has(snap.ref.path) && !isDeepStrictEqual(data, updated))
      associated.push({ snap, updated });
    for (const child of await snap.ref.listCollections()) await scan(child);
  }
}
for (const collection of await db.listCollections()) await scan(collection);
console.log(JSON.stringify({ accounts: pairs.map(p => ({ role:p.role,email:p.email,uid:p.user.uid })), associatedDocuments: associated.length }));
if (!process.argv.includes('--apply') || !pairs.length) process.exit(0);

// Local recovery copy of original registration/reference documents; no tokens or passwords.
const backupDir = join(tmpdir(), 'cone-email-migration'); mkdirSync(backupDir, {recursive:true});
const backup = join(backupDir, `${Date.now()}.json`);
writeFileSync(backup, JSON.stringify({ projectId:'conferencemanagement-239a3', accounts:pairs.map(p => ({uid:p.user.uid,email:p.oldEmail,newEmail:p.email,emailVerified:p.user.emailVerified})), documents:[...pairs.map(p=>p.oldDoc),...associated.map(p=>p.snap)].map(d=>({path:d.ref.path,data:d.data()})) },null,2), {mode:0o600});
console.log(`Recovery snapshot: ${backup}`);
const changed = [];
try {
  for (const p of pairs) {
    await auth.updateUser(p.user.uid, {email:p.email,emailVerified:p.user.emailVerified}); changed.push(p);
  }
  await db.runTransaction(async tx => {
    // Check every document before any write so concurrent edits are never overwritten.
    const sources = [...pairs.map(p=>p.oldDoc), ...associated.map(p=>p.snap)];
    const current = await tx.getAll(...sources.map(s=>s.ref), ...pairs.map(p=>db.doc(`people/${p.email}`)));
    sources.forEach((s,i)=> {
      if (!current[i].exists || !current[i].updateTime.isEqual(s.updateTime))
        throw new Error(`Concurrent change at ${s.ref.path}; migration cancelled`);
    });
    if (current.slice(sources.length).some(s=>s.exists)) throw new Error('Destination was created concurrently');
    for (const p of pairs) {
      tx.create(db.doc(`people/${p.email}`), replace(p.oldDoc.data()));
      tx.delete(p.oldDoc.ref);
    }
    for (const p of associated) tx.set(p.snap.ref,p.updated);
  });
} catch (error) {
  for (const p of changed.reverse()) {
    try { await auth.updateUser(p.user.uid, {email:p.oldEmail,emailVerified:p.user.emailVerified}); }
    catch { console.error(`Auth rollback failed for UID ${p.user.uid}; use the recovery snapshot.`); }
  }
  throw error;
}
for (const p of pairs) {
  const [user, snap, old] = await Promise.all([auth.getUser(p.user.uid),db.doc(`people/${p.email}`).get(),p.oldDoc.ref.get()]);
  if (user.email !== p.email || user.emailVerified !== p.user.emailVerified || old.exists ||
      !isDeepStrictEqual(snap.data(), replace(p.oldDoc.data())))
    throw new Error(`Post-migration verification failed for ${p.role}; use recovery snapshot.`);
}
for (const p of associated)
  if (!isDeepStrictEqual((await p.snap.ref.get()).data(),p.updated))
    throw new Error(`Reference verification failed at ${p.snap.ref.path}`);
console.log('Verified: six account mappings, original Auth UIDs and all non-email registration fields preserved; associated references updated. No emails sent.');
