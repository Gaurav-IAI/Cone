// Checks real Firebase passwordless sign-in and Firestore access without sending mail.
import { readFileSync } from 'node:fs';
import { initializeApp,applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { isDeepStrictEqual } from 'node:util';
const project = 'conferencemanagement-239a3';
initializeApp({credential:applicationDefault(),projectId:project});
const auth=getAuth(), db=getFirestore();
const config=JSON.parse(readFileSync(new URL('../../android/app/google-services.json',import.meta.url),'utf8'));
const client=config.client.find(c=>c.client_info.android_client_info.package_name==='com.usstc.usstc_conferenc');
const key=client.api_key[0].current_key;
const seed=JSON.parse(readFileSync(new URL('./seed_data.json',import.meta.url),'utf8'));
for(const p of seed.people) {
  const user=await auth.getUserByEmail(p.email);
  const before=(await db.doc(`people/${p.email}`).get()).data();
  for(const field of ['email','fullName','mobile','role','registrationId','passId'])
    if(before[field]!==p[field])throw new Error(`Registration mismatch: ${p.role} ${field}`);
  const link=await auth.generateSignInWithEmailLink(p.email,{
    url:`https://${project}.firebaseapp.com/finishSignIn`,handleCodeInApp:true,
    android:{packageName:'com.usstc.usstc_conferenc',installApp:false,minimumVersion:'1'},
  });
  let uri=new URL(link);
  if(!uri.searchParams.has('oobCode'))uri=new URL(uri.searchParams.get('link'));
  const response=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithEmailLink?key=${key}`,{
    method:'POST',headers:{'Content-Type':'application/json'},
    body:JSON.stringify({email:p.email,oobCode:uri.searchParams.get('oobCode')}),
  });
  const result=await response.json();
  if(!response.ok)throw new Error(`${p.role}: ${result.error?.message||response.status}`);
  if(result.localId!==user.uid||result.email!==p.email)throw new Error(`UID/email mismatch: ${p.role}`);
  const read=await fetch(`https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents/people/${encodeURIComponent(p.email)}`,{
    headers:{Authorization:`Bearer ${result.idToken}`},
  });
  if(!read.ok)throw new Error(`Firestore login access failed: ${p.role} (${read.status})`);
  if(!isDeepStrictEqual((await db.doc(`people/${p.email}`).get()).data(),before))throw new Error(`Registration changed while checking ${p.role}`);
  console.log(`${p.role}: real Firebase sign-in and own-registration access passed; original UID retained; no email sent.`);
}
