'use client';

import { getApp, getApps, initializeApp, type FirebaseApp } from 'firebase/app';
import { getAuth, type Auth } from 'firebase/auth';

/** The app's own Firebase project (public client config, `.env.local`). */
function app(): FirebaseApp {
  if (getApps().length > 0) return getApp();
  return initializeApp({
    apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? '',
    authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN ?? '',
    projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? '',
  });
}

export function firebaseAuth(): Auth {
  return getAuth(app());
}

export const firebaseConfigured = (): boolean =>
  (process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? '') !== '' && (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? '') !== '';
