/**
 * In-memory TokenVerifier for tests. Tokens are scripted strings; no crypto,
 * no network, no Firebase project. The route layer cannot tell the difference,
 * which is the point of the seam.
 */
import {
  TokenVerificationError,
  type TokenFailureReason,
  type TokenVerifier,
  type VerifiedIdentity,
} from '../lib/token-verifier.js';

type Scripted = { kind: 'ok'; identity: VerifiedIdentity } | { kind: 'fail'; reason: TokenFailureReason };

export class FakeTokenVerifier implements TokenVerifier {
  readonly #tokens = new Map<string, Scripted>();
  readonly revoked: string[] = [];

  /** Registers a token that verifies to the given identity. Returns the token. */
  accept(token: string, identity: Partial<VerifiedIdentity> & { uid: string }): string {
    this.#tokens.set(token, {
      kind: 'ok',
      identity: {
        uid: identity.uid,
        email: identity.email ?? null,
        emailVerified: identity.emailVerified ?? true,
        claims: identity.claims ?? {},
      },
    });
    return token;
  }

  /** Registers a token that fails for a specific reason. Returns the token. */
  reject(token: string, reason: TokenFailureReason): string {
    this.#tokens.set(token, { kind: 'fail', reason });
    return token;
  }

  async verifyIdToken(idToken: string): Promise<VerifiedIdentity> {
    const scripted = this.#tokens.get(idToken);
    if (scripted === undefined) throw new TokenVerificationError('malformed', 'unknown token');
    if (scripted.kind === 'fail') throw new TokenVerificationError(scripted.reason, scripted.reason);
    return scripted.identity;
  }

  async revokeRefreshTokens(uid: string): Promise<void> {
    this.revoked.push(uid);
  }
}
