/**
 * Phase 17 (§23.3, ADR-023 D3) — removing the Firebase sign-in account when a
 * user deletes theirs, so the email and the sign-in go too. A seam, like the
 * token verifier: tests record calls; nothing reaches Firebase.
 */
import { getAuth } from 'firebase-admin/auth';

import { firebaseApp, type FirebaseVerifierOptions } from './token-verifier.js';

declare module 'fastify' {
  interface FastifyInstance {
    accountDeleter: AccountDeleter;
  }
}

export interface AccountDeleter {
  /** Removes the sign-in account; an account already gone is success. */
  deleteAccount(firebaseUid: string): Promise<void>;
}

export class FirebaseAccountDeleter implements AccountDeleter {
  constructor(private readonly options: FirebaseVerifierOptions) {}

  async deleteAccount(firebaseUid: string): Promise<void> {
    try {
      await getAuth(firebaseApp(this.options)).deleteUser(firebaseUid);
    } catch (e) {
      if ((e as { code?: string }).code === 'auth/user-not-found') return;
      throw e;
    }
  }
}

/** For test apps built with a scripted token verifier: there is no Firebase account to remove. */
export class RecordingAccountDeleter implements AccountDeleter {
  readonly deleted: string[] = [];
  fail = false;

  async deleteAccount(firebaseUid: string): Promise<void> {
    if (this.fail) throw new Error('scripted failure');
    this.deleted.push(firebaseUid);
  }
}
