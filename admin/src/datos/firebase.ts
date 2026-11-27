/**
 * Conexión a Firebase. Por defecto usa los emuladores locales
 * (mismo proyecto demo-mican que `npm run serve` en functions/).
 * Para el proyecto real, ver admin/README.md y .env.example.
 */
import { initializeApp } from "firebase/app";
import { connectAuthEmulator, getAuth } from "firebase/auth";
import { connectFirestoreEmulator, getFirestore } from "firebase/firestore";
import { connectFunctionsEmulator, getFunctions } from "firebase/functions";
import { connectStorageEmulator, getStorage } from "firebase/storage";

const env = import.meta.env;

export const USAR_EMULADORES = env.VITE_USAR_EMULADORES !== "false";
const HOST = env.VITE_HOST_EMULADOR || "127.0.0.1";
const PROYECTO = env.VITE_FIREBASE_PROJECT_ID || "demo-mican";

/** Región de las Cloud Functions (functions/src/lib/firebase.ts). */
export const REGION_FUNCIONES = "southamerica-east1";

export const app = initializeApp({
  apiKey: env.VITE_FIREBASE_API_KEY || "clave-de-relleno-para-emuladores",
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN || `${PROYECTO}.firebaseapp.com`,
  projectId: PROYECTO,
  storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET || `${PROYECTO}.appspot.com`,
  appId: env.VITE_FIREBASE_APP_ID || "1:000000000000:web:0000000000000000",
});

export const auth = getAuth(app);
export const db = getFirestore(app);
export const funciones = getFunctions(app, REGION_FUNCIONES);
export const storage = getStorage(app);

if (USAR_EMULADORES) {
  connectAuthEmulator(auth, `http://${HOST}:9099`, { disableWarnings: true });
  connectFirestoreEmulator(db, HOST, 8080);
  connectFunctionsEmulator(funciones, HOST, 5001);
  connectStorageEmulator(storage, HOST, 9199);
}
