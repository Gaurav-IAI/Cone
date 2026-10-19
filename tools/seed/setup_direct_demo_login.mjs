// Configure ONLY the six existing fictional demo accounts for direct mobile login.
// Passwords are test-only credentials bundled in a local testing APK, never admin keys.
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
const projectId='conferencemanagement-239a3';
if(process.env.FIRESTORE_EMULATOR_HOST||process.env.FIREBASE_AUTH_EMULATOR_HOST)throw Error('Live demo configuration must not use emulators');
initializeApp({credential:applicationDefault(),projectId});
const auth=getAuth(),db=getFirestore();
const seed=JSON.parse(readFileSync(new URL('./seed_data.json',import.meta.url),'utf8'));
const directory=new URL('../../assets/testing/',import.meta.url);
const file=new URL('demo_login.json',directory);
mkdirSync(directory,{recursive:true});
const existing=existsSync(file)?JSON.parse(readFileSync(file,'utf8')):{};
const accounts=[];
// Validate all six before changing credentials; never create a new or non-demo user.
for(const p of seed.people){
 const d=(await db.doc(`people/${p.email}`).get()).data();
 if(!d||!d.isDemo)throw Error(`Not a demo registration: ${p.role}`);
 for(const field of ['fullName','email','mobile','role','registrationId'])if(d[field]!==p[field])throw Error(`Identity mismatch: ${p.role}`);
 const user=await auth.getUserByEmail(p.email);
 if(user.disabled)throw Error(`Disabled account: ${p.role}`);
 accounts.push({email:p.email,name:d.fullName,mobile:d.mobile,role:d.role,uid:user.uid,password:existing.accounts?.find(x=>x.email===p.email)?.password??randomBytes(32).toString('base64url')});
}
// Save first, so a partially completed run can resume using the same demo credentials.
writeFileSync(file,JSON.stringify({isDemo:true,accounts},null,2)+'\n',{mode:0o600});
const config=JSON.parse(readFileSync(new URL('../../android/app/google-services.json',import.meta.url),'utf8'));
const key=config.client.find(c=>c.client_info.android_client_info.package_name==='com.usstc.usstc_conferenc').api_key[0].current_key;
for(const a of accounts){
 await auth.updateUser(a.uid,{password:a.password,emailVerified:true});
 await db.doc(`people/${a.email}`).update({emailVerified:true,emailVerificationStatus:'Verified'});
 const response=await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${key}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:a.email,password:a.password,returnSecureToken:true})});
 const result=await response.json();
 if(!response.ok||result.localId!==a.uid)throw Error(`${a.role}: direct Firebase login failed (${result.error?.message??response.status})`);
 const doc=await fetch(`https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/people/${encodeURIComponent(a.email)}`,{headers:{Authorization:`Bearer ${result.idToken}`}});
 if(!doc.ok)throw Error(`${a.role}: database access failed (${doc.status})`);
 const record=(await db.doc(`people/${a.email}`).get()).data();
 for(const field of ['fullName','email','mobile','role','registrationId','passId']){
  const source=seed.people.find(p=>p.email===a.email);
  if(record[field]!==source[field])throw Error(`${a.role}: unexpected record change`);
 }
 console.log(`${a.role}: direct Firebase login + database access passed, original UID retained, Verified persisted. No API, links, OTP or email.`);
}
console.log('Local testing APK credentials prepared. Do not publish this demo credential asset as production authentication.');
