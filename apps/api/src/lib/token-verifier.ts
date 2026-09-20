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
   * Path to a service-account JSON. Omit on Cloud Run, where Application
   * Default Credentials come from the runtime with no file at all (§24).
   */
  readonly credentialsPath?: string | undefined;
}

function firebaseApp(options: FirebaseVerifierOptions): App {
  const existing = getApps()[0];
  if (existing !== undefined) return existing;

  const credential =
    options.credentialsPath !== undefined
      ? cert(JSON.parse(readFileSync(options.credentialsPath, 'utf8')) as Parameters<typeof cert>[0])
      : applicationDefault();

  return initializeApp({ credential, projectId: options.projectId });
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
