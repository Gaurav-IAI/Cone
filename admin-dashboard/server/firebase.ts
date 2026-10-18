import "dotenv/config";
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
initializeApp({
  projectId: process.env.FIREBASE_PROJECT_ID,
  ...(process.env.FIRESTORE_EMULATOR_HOST
    ? {}
    : { credential: applicationDefault() }),
});
export const db = getFirestore();
export const auth = getAuth();
