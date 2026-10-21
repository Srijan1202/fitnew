'use client';

import { GoogleAuthProvider, onIdTokenChanged, signInWithEmailAndPassword, signInWithPopup, signOut, type User } from 'firebase/auth';
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';

import { api, ApiError } from './api';
import { firebaseAuth, firebaseConfigured } from './firebase';

export type AdminState =
  | { readonly kind: 'loading' }
  | { readonly kind: 'not-configured' }
  | { readonly kind: 'signed-out' }
  | { readonly kind: 'not-admin'; readonly email: string | null }
  | { readonly kind: 'admin'; readonly email: string | null; readonly user: User }
  | { readonly kind: 'error'; readonly message: string };

interface AuthApi {
  readonly state: AdminState;
  signInGoogle(): Promise<void>;
  signInEmail(email: string, password: string): Promise<void>;
  signOutNow(): Promise<void>;
  recheck(): Promise<void>;
}

const Ctx = createContext<AuthApi | null>(null);

/**
 * Sign-in for the admin panel: the app's own Firebase accounts. After sign-in
 * the API is asked whether this account is an administrator (GET /admin/me);
 * the claim lives in the Firebase token and is checked there, on every call.
 */
export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AdminState>({ kind: 'loading' });

  const check = useCallback(async (user: User | null) => {
    if (user === null) {
      setState({ kind: 'signed-out' });
      return;
    }
    try {
      // The API needs a user row for the audit trail's actor.
      await api('POST', '/auth/session', {});
      await api('GET', '/admin/me');
      setState({ kind: 'admin', email: user.email, user });
    } catch (e) {
      if (e instanceof ApiError && e.status === 403) setState({ kind: 'not-admin', email: user.email });
      else setState({ kind: 'error', message: e instanceof Error ? e.message : 'The API could not be reached.' });
    }
  }, []);

  useEffect(() => {
    if (!firebaseConfigured()) {
      setState({ kind: 'not-configured' });
      return;
    }
    return onIdTokenChanged(firebaseAuth(), (u) => void check(u));
  }, [check]);

  const value = useMemo<AuthApi>(
    () => ({
      state,
      signInGoogle: async () => {
        await signInWithPopup(firebaseAuth(), new GoogleAuthProvider());
      },
      signInEmail: async (email, password) => {
        await signInWithEmailAndPassword(firebaseAuth(), email, password);
      },
      signOutNow: async () => {
        await signOut(firebaseAuth());
      },
      recheck: async () => {
        const u = firebaseAuth().currentUser;
        // A fresh token carries a newly granted claim.
        if (u !== null) await u.getIdToken(true);
        await check(u);
      },
    }),
    [state, check],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthApi {
  const c = useContext(Ctx);
  if (c === null) throw new Error('useAuth outside AuthProvider');
  return c;
}
