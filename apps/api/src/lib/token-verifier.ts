/**
 * Token verification seam.
 *
 * Everything the API knows about a caller's identity comes through this
 * interface. Production wraps firebase-admin; tests inject a fake with
 * scripted tokens. Routes and services never import firebase-admin directly,
 * so identity can be verified in tests without a network, a project, or a key.
 */
import { applicationDefault, cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getAuth, type DecodedIdToken as FirebaseDecodedIdToken } from 'firebase-admin/auth';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

/** What a verified token tells us. Deliberately narrow. */
export interface VerifiedIdentity {
  /** Firebase UID — the join key to `users.firebase_uid`. */
  readonly uid: string;
  readonly email: string | null;
  readonly emailVerified: boolean;
  /** Custom claims, e.g. `{ role: 'admin' }` (§11). */
  readonly claims: Readonly<Record<string, unknown>>;
}

export type TokenFailureReason = 'expired' | 'revoked' | 'malformed' | 'unknown';

/** Thrown by a verifier. The route layer maps every reason to 401. */
export class TokenVerificationError extends Error {
  readonly reason: TokenFailureReason;

  constructor(reason: TokenFailureReason, message: string) {
    super(message);
    this.name = 'TokenVerificationError';
    this.reason = reason;
  }
}

export interface TokenVerifier {
  /**
   * Resolves the identity behind an ID token, or throws
   * `TokenVerificationError`. Must check revocation: a signed-out user's
   * still-unexpired token must not keep working (§11, DELETE /auth/session).
   */
  verifyIdToken(idToken: string): Promise<VerifiedIdentity>;

  /** Invalidates every refresh token for the user. Used by sign-out. */
  revokeRefreshTokens(uid: string): Promise<void>;
}

/* ------------------------------------------------------------ the cache -- */

/**
 * Beta 6.2 (audit 2026-11-11 S9): a verified token is trusted for up to
 * [ttlMs] (never past its own expiry) without asking Firebase again, so a
 * slow or unreachable Firebase does not slow or stop every request. Sign-out,
 * an admin role change and account deletion on this server forget the
 * person's tokens at once; a revocation made elsewhere bites within [ttlMs].
 * Keys are SHA-256 digests: no token is kept in memory as it was sent.
 */
export class VerifiedTokenCache {
  readonly #entries = new Map<string, { identity: VerifiedIdentity; until: number }>();

  constructor(
    readonly ttlMs = 60_000,
    readonly max = 10_000,
    private readonly now: () => number = () => Date.now(),
  ) {}

  static #key(token: string): string {
    return createHash('sha256').update(token).digest('base64url');
  }

  get size(): number {
    return this.#entries.size;
  }

  get(token: string): VerifiedIdentity | null {
    const key = VerifiedTokenCache.#key(token);
    const e = this.#entries.get(key);
    if (e === undefined) return null;
    if (e.until <= this.now()) {
      this.#entries.delete(key);
      return null;
    }
    return e.identity;
  }

  /** `expiresAtMs`: the token's own expiry; nothing is kept past it. */
  set(token: string, identity: VerifiedIdentity, expiresAtMs: number): void {
    const now = this.now();
    const until = Math.min(now + this.ttlMs, expiresAtMs);
    if (until <= now) return;
    if (this.#entries.size >= this.max) {
      for (const [k, e] of this.#entries) if (e.until <= now) this.#entries.delete(k);
      // Still full: the oldest goes (a Map keeps insertion order).
      if (this.#entries.size >= this.max) this.#entries.delete(this.#entries.keys().next().value!);
    }
    this.#entries.set(VerifiedTokenCache.#key(token), { identity, until });
  }

  /** Every cached token of this person goes. */
  forgetUid(uid: string): void {
    for (const [k, e] of this.#entries) if (e.identity.uid === uid) this.#entries.delete(k);
  }
}

/** The server's one cache (the verifier, the account deleter and the admin directory share it). */
export const verifiedTokens = new VerifiedTokenCache();

/* --------------------------------------------------------------- firebase -- */

export interface FirebaseVerifierOptions {
  readonly projectId: string;
  /**
   * Path to a service-account JSON, or (on AWS, ADR-025) a Workload Identity
   * Federation configuration. Omit on Cloud Run, where Application Default
   * Credentials come from the runtime with no file at all (§24).
   */
  readonly credentialsPath?: string | undefined;
}

/**
 * Phase 19 (ADR-025) — what kind of Google credential a file holds.
 *
 * - `service_account`: a key (the LAN PC; the hosted fallback).
 * - anything else (`external_account`, i.e. Workload Identity Federation from
 *   AWS): a configuration with no secret in it. Google's auth library
 *   exchanges the server's own AWS identity for a short-lived Google token,
 *   so a server on AWS reaches Firebase with no key, as one on Cloud Run does.
 */
export function credentialFileKind(json: unknown): 'service-account' | 'application-default' {
  const type = (json as { type?: unknown } | null)?.type;
  return type === 'service_account' ? 'service-account' : 'application-default';
}

export function firebaseApp(options: FirebaseVerifierOptions): App {
  const existing = getApps()[0];
  if (existing !== undefined) return existing;

  return initializeApp({ credential: credentialFor(options.credentialsPath), projectId: options.projectId });
}

function credentialFor(path: string | undefined): ReturnType<typeof applicationDefault> {
  if (path === undefined) return applicationDefault();
  const json = JSON.parse(readFileSync(path, 'utf8')) as unknown;
  if (credentialFileKind(json) === 'service-account') return cert(json as Parameters<typeof cert>[0]);
  // The library reads the file from this variable; make sure it is the same
  // file whichever way the path arrived.
  process.env['GOOGLE_APPLICATION_CREDENTIALS'] = path;
  return applicationDefault();
}

function classify(error: unknown): TokenFailureReason {
  const code = (error as { code?: string } | null)?.code ?? '';
  if (code === 'auth/id-token-expired') return 'expired';
  if (code === 'auth/id-token-revoked') return 'revoked';
  if (code === 'auth/argument-error' || code === 'auth/invalid-id-token') return 'malformed';
  return 'unknown';
}

const RESERVED_CLAIMS = new Set([
  'aud', 'auth_time', 'exp', 'firebase', 'iat', 'iss', 'sub', 'uid', 'email', 'email_verified',
  'phone_number', 'picture', 'name',
]);

function customClaims(decoded: FirebaseDecodedIdToken): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(decoded)) {
    if (!RESERVED_CLAIMS.has(key)) out[key] = value;
  }
  return out;
}

export class FirebaseTokenVerifier implements TokenVerifier {
  readonly #app: App;

  constructor(options: FirebaseVerifierOptions) {
    this.#app = firebaseApp(options);
  }

  async verifyIdToken(idToken: string): Promise<VerifiedIdentity> {
    const cached = verifiedTokens.get(idToken);
    if (cached !== null) return cached;
    let decoded: FirebaseDecodedIdToken;
    try {
      // checkRevoked=true costs a round trip to Firebase but is what makes
      // sign-out actually mean something before the token's natural expiry.
      decoded = await getAuth(this.#app).verifyIdToken(idToken, true);
    } catch (error) {
      const reason = classify(error);
      throw new TokenVerificationError(reason, `ID token ${reason}`);
    }
    const identity: VerifiedIdentity = {
      uid: decoded.uid,
      email: decoded.email ?? null,
      emailVerified: decoded.email_verified ?? false,
      claims: customClaims(decoded),
    };
    verifiedTokens.set(idToken, identity, decoded.exp * 1000);
    return identity;
  }

  async revokeRefreshTokens(uid: string): Promise<void> {
    verifiedTokens.forgetUid(uid);
    await getAuth(this.#app).revokeRefreshTokens(uid);
  }
}
