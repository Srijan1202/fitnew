/**
 * Session orchestration. Takes a verified identity (never a raw token, never a
 * client-supplied id) and returns the app-facing profile.
 */
import type { VerifiedIdentity } from '../../lib/token-verifier.js';
import type { UsersRepository } from './repository.js';
import {
  DEFAULT_LOCALE,
  DEFAULT_TIME_ZONE,
  type CreateSessionRequest,
  type CreateSessionResponse,
} from './schemas.js';

export class AuthService {
  constructor(private readonly users: UsersRepository) {}

  /**
   * Idempotent: the first call for a uid creates the row, every later call
   * returns it. `isNewUser` is true exactly once.
   */
  async createSession(
    identity: VerifiedIdentity,
    request: CreateSessionRequest,
  ): Promise<CreateSessionResponse> {
    const { row, inserted } = await this.users.upsertByFirebaseUid({
      firebaseUid: identity.uid,
      email: identity.email,
      timezone: request.timezone ?? DEFAULT_TIME_ZONE,
      locale: request.locale ?? DEFAULT_LOCALE,
    });

    return {
      user: {
        id: row.id,
        email: row.email,
        timezone: row.timezone,
        locale: row.locale,
        createdAt: row.createdAt.toISOString(),
      },
      isNewUser: inserted,
    };
  }
}
