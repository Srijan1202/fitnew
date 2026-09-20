/**
 * AuthService with a mocked repository (§26.1: services are unit-tested
 * against a mocked repository).
 */
import { describe, expect, it, vi } from 'vitest';

import type { VerifiedIdentity } from '../../lib/token-verifier.js';
import type { UpsertUserInput, UpsertUserResult, UsersRepository } from './repository.js';
import { AuthService } from './service.js';

const identity: VerifiedIdentity = {
  uid: 'firebase-uid-1',
  email: 'student@vit.ac.in',
  emailVerified: true,
  claims: {},
};

function mockRepo(inserted: boolean) {
  const upsertByFirebaseUid = vi.fn(
    async (input: UpsertUserInput): Promise<UpsertUserResult> => ({
      inserted,
      row: {
        id: '4f0b9a2e-1c2d-4e3f-8a9b-0c1d2e3f4a5b',
        firebaseUid: input.firebaseUid,
        email: input.email,
        timezone: input.timezone,
        locale: input.locale,
        createdAt: new Date('2026-09-20T10:00:00Z'),
        updatedAt: new Date('2026-09-20T10:00:00Z'),
        deletedAt: null,
      },
    }),
  );
  return { repo: { upsertByFirebaseUid } as unknown as UsersRepository, upsertByFirebaseUid };
}

describe('AuthService.createSession', () => {
  it('is new exactly when the repository inserted', async () => {
    const first = new AuthService(mockRepo(true).repo);
    expect((await first.createSession(identity, {})).isNewUser).toBe(true);

    const later = new AuthService(mockRepo(false).repo);
    expect((await later.createSession(identity, {})).isNewUser).toBe(false);
  });

  it('takes identity from the verified token, never from the request', async () => {
    const { repo, upsertByFirebaseUid } = mockRepo(true);
    await new AuthService(repo).createSession(identity, {});
    expect(upsertByFirebaseUid).toHaveBeenCalledWith(
      expect.objectContaining({ firebaseUid: 'firebase-uid-1', email: 'student@vit.ac.in' }),
    );
  });

  it('applies India defaults when the client sends nothing', async () => {
    const { repo, upsertByFirebaseUid } = mockRepo(true);
    await new AuthService(repo).createSession(identity, {});
    expect(upsertByFirebaseUid).toHaveBeenCalledWith(
      expect.objectContaining({ timezone: 'Asia/Kolkata', locale: 'en-IN' }),
    );
  });

  it('passes the client zone and locale through when given', async () => {
    const { repo, upsertByFirebaseUid } = mockRepo(true);
    await new AuthService(repo).createSession(identity, {
      timezone: 'Europe/London',
      locale: 'en-GB',
    });
    expect(upsertByFirebaseUid).toHaveBeenCalledWith(
      expect.objectContaining({ timezone: 'Europe/London', locale: 'en-GB' }),
    );
  });

  it('returns the profile shape with an ISO timestamp and no uid', async () => {
    const result = await new AuthService(mockRepo(true).repo).createSession(identity, {});
    expect(result.user).toEqual({
      id: '4f0b9a2e-1c2d-4e3f-8a9b-0c1d2e3f4a5b',
      email: 'student@vit.ac.in',
      timezone: 'Asia/Kolkata',
      locale: 'en-IN',
      createdAt: '2026-09-20T10:00:00.000Z',
    });
    // The Firebase uid is an internal join key, not part of the app profile.
    expect(result.user).not.toHaveProperty('firebaseUid');
  });
});
