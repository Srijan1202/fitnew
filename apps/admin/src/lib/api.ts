'use client';

import { firebaseAuth } from './firebase';

/** The API's error envelope, as a thrown error with the server's own words. */
export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

/**
 * Calls the FITOS API through this server's `/api` proxy, with the signed-in
 * user's Firebase ID token. Every admin route checks the `role: admin`
 * claim on the server; this client decides nothing.
 */
export async function api<T>(method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE', path: string, body?: unknown): Promise<T> {
  const user = firebaseAuth().currentUser;
  if (user === null) throw new ApiError(401, 'UNAUTHENTICATED', 'Sign in to continue.');
  const token = await user.getIdToken();
  const res = await fetch(`/api/v1${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, ...(body !== undefined ? { 'content-type': 'application/json' } : {}) },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
    cache: 'no-store',
  });
  if (res.status === 204) return undefined as T;
  const text = await res.text();
  const json = text === '' ? null : (JSON.parse(text) as unknown);
  if (!res.ok) {
    const e = (json as { error?: { code?: string; message?: string } } | null)?.error;
    throw new ApiError(res.status, e?.code ?? 'UNKNOWN', e?.message ?? `The API answered ${res.status}.`);
  }
  return json as T;
}

/** Beta 3.6: a file the API serves (a feedback picture), with the same sign-in. */
export async function apiBlob(path: string): Promise<Blob> {
  const user = firebaseAuth().currentUser;
  if (user === null) throw new ApiError(401, 'UNAUTHENTICATED', 'Sign in to continue.');
  const token = await user.getIdToken();
  const res = await fetch(`/api/v1${path}`, { headers: { authorization: `Bearer ${token}` }, cache: 'no-store' });
  if (!res.ok) throw new ApiError(res.status, 'UNKNOWN', `The API answered ${res.status}.`);
  return res.blob();
}

export const errorText = (e: unknown): string => (e instanceof Error ? e.message : 'Something went wrong.');
