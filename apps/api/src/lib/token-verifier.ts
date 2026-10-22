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
    let decoded: FirebaseDecodedIdToken;
    try {
      // checkRevoked=true costs a round trip to Firebase but is what makes
      // sign-out actually mean something before the token's natural expiry.
      decoded = await getAuth(this.#app).verifyIdToken(idToken, true);
    } catch (error) {
      const reason = classify(error);
      throw new TokenVerificationError(reason, `ID token ${reason}`);
    }
    return {
      uid: decoded.uid,
      email: decoded.email ?? null,
      emailVerified: decoded.email_verified ?? false,
      claims: customClaims(decoded),
    };
  }

  async revokeRefreshTokens(uid: string): Promise<void> {
    await getAuth(this.#app).revokeRefreshTokens(uid);
  }
}
