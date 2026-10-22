/**
 * Who is an administrator (ADR-022 D2 and its amendment): the Firebase custom
 * claim `role: admin`. A seam, like the token verifier and the account
 * deleter. Production reads and writes Firebase; test apps get an in-memory
 * directory they can seed, and nothing reaches Firebase.
 */
import { getAuth, type UserRecord } from 'firebase-admin/auth';

import { firebaseApp, type FirebaseVerifierOptions } from './token-verifier.js';

declare module 'fastify' {
  interface FastifyInstance {
    adminDirectory: AdminDirectory;
  }
}

export interface DirectoryAccount {
  readonly uid: string;
  readonly email: string | null;
  readonly lastSignInAt: Date | null;
  readonly admin: boolean;
}

export interface AdminDirectory {
  /** Every account with `role: admin`. */
  listAdmins(): Promise<DirectoryAccount[]>;
  /** The sign-in account with this email, or null. */
  findByEmail(email: string): Promise<DirectoryAccount | null>;
  findByUid(uid: string): Promise<DirectoryAccount | null>;
  /** Sets or removes `role: admin`, keeping any other claim. */
  setAdmin(uid: string, admin: boolean): Promise<void>;
  /** Ends every session now: the API checks revocation on every token. */
  revokeSessions(uid: string): Promise<void>;
}

const isAdmin = (claims: Record<string, unknown> | undefined): boolean => claims?.['role'] === 'admin';

function account(u: UserRecord): DirectoryAccount {
  const last = u.metadata.lastSignInTime;
  return { uid: u.uid, email: u.email ?? null, lastSignInAt: last ? new Date(last) : null, admin: isAdmin(u.customClaims) };
}

const notFound = (e: unknown): boolean => (e as { code?: string } | null)?.code === 'auth/user-not-found';

export class FirebaseAdminDirectory implements AdminDirectory {
  constructor(private readonly options: FirebaseVerifierOptions) {}

  private auth() {
    return getAuth(firebaseApp(this.options));
  }

  async listAdmins(): Promise<DirectoryAccount[]> {
    const out: DirectoryAccount[] = [];
    let page: string | undefined;
    do {
      const r = await this.auth().listUsers(1000, page);
      for (const u of r.users) if (isAdmin(u.customClaims)) out.push(account(u));
      page = r.pageToken;
    } while (page !== undefined);
    return out;
  }

  async findByEmail(email: string): Promise<DirectoryAccount | null> {
    try {
      return account(await this.auth().getUserByEmail(email));
    } catch (e) {
      if (notFound(e)) return null;
      throw e;
    }
  }

  async findByUid(uid: string): Promise<DirectoryAccount | null> {
    try {
      return account(await this.auth().getUser(uid));
    } catch (e) {
      if (notFound(e)) return null;
      throw e;
    }
  }

  async setAdmin(uid: string, admin: boolean): Promise<void> {
    const user = await this.auth().getUser(uid);
    const claims: Record<string, unknown> = { ...(user.customClaims ?? {}) };
    if (admin) claims['role'] = 'admin';
    else delete claims['role'];
    await this.auth().setCustomUserClaims(uid, claims);
  }

  async revokeSessions(uid: string): Promise<void> {
    await this.auth().revokeRefreshTokens(uid);
  }
}

/** For test apps: accounts a test adds; records revocations. */
export class InMemoryAdminDirectory implements AdminDirectory {
  readonly accounts = new Map<string, { email: string | null; admin: boolean; lastSignInAt: Date | null }>();
  readonly revoked: string[] = [];

  add(uid: string, email: string | null, admin = false): void {
    this.accounts.set(uid, { email, admin, lastSignInAt: null });
  }

  private view(uid: string): DirectoryAccount | null {
    const a = this.accounts.get(uid);
    return a === undefined ? null : { uid, ...a };
  }

  async listAdmins(): Promise<DirectoryAccount[]> {
    return [...this.accounts.keys()].map((uid) => this.view(uid)!).filter((a) => a.admin);
  }

  async findByEmail(email: string): Promise<DirectoryAccount | null> {
    const hit = [...this.accounts.entries()].find(([, a]) => a.email?.toLowerCase() === email.toLowerCase());
    return hit === undefined ? null : this.view(hit[0]);
  }

  async findByUid(uid: string): Promise<DirectoryAccount | null> {
    return this.view(uid);
  }

  async setAdmin(uid: string, admin: boolean): Promise<void> {
    const a = this.accounts.get(uid);
    if (a === undefined) throw Object.assign(new Error('no user'), { code: 'auth/user-not-found' });
    a.admin = admin;
  }

  async revokeSessions(uid: string): Promise<void> {
    this.revoked.push(uid);
  }
}
