/**
 * /v1/auth/session — HTTP and Zod only (§8.3). Identity comes from
 * `request.identity`, populated by the auth plugin; this file never sees a
 * raw token.
 *
 * Both routes are protected by the default-deny hook: you must already hold a
 * valid Firebase ID token to exchange it for an app session, and to sign out.
 * That is the §11 flow — Firebase authenticates, we authorise.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import { errorEnvelopeSchema } from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { UsersRepository } from './repository.js';
import { createSessionRequestSchema, createSessionResponseSchema } from './schemas.js';
import { AuthService } from './service.js';

/** §10: /auth/session is 10/min/IP — stricter than the 120/min default. */
const AUTH_RATE_LIMIT = { max: 10, timeWindow: '1 minute' } as const;

export async function authRoutes(app: FastifyInstance): Promise<void> {
  const service = new AuthService(new UsersRepository(app.database.db));
  const typed = app.withTypeProvider<ZodTypeProvider>();

  typed.post(
    '/auth/session',
    {
      config: { rateLimit: AUTH_RATE_LIMIT },
      schema: {
        summary: 'Exchange a Firebase ID token for an app session',
        description:
          'Idempotent. Creates the user row on first sign-in and returns it on every later call. ' +
          'Identity is taken from the verified Bearer token; the body carries device context only.',
        tags: ['auth'],
        security: [{ bearerAuth: [] }],
        body: createSessionRequestSchema,
        response: {
          200: createSessionResponseSchema,
          401: errorEnvelopeSchema,
          422: errorEnvelopeSchema,
          429: errorEnvelopeSchema,
        },
      },
    },
    async (request, reply) => {
      const identity = request.identity;
      if (identity === null) {
        // Unreachable when the auth hook is registered; kept so a misconfigured
        // app fails closed rather than creating an anonymous row.
        throw new AppError('UNAUTHENTICATED', 'Sign in to continue.');
      }
      const result = await service.createSession(identity, request.body);
      return reply.status(200).send(result);
    },
  );

  typed.delete(
    '/auth/session',
    {
      config: { rateLimit: AUTH_RATE_LIMIT },
      schema: {
        summary: 'Sign out: revoke every refresh token for the caller',
        description:
          'After this, the client must discard its tokens. Because verification checks revocation, ' +
          'an unexpired ID token issued before this call stops working too.',
        tags: ['auth'],
        security: [{ bearerAuth: [] }],
        response: {
          204: z.null().describe('Signed out'),
          401: errorEnvelopeSchema,
          429: errorEnvelopeSchema,
        },
      },
    },
    async (request, reply) => {
      const identity = request.identity;
      if (identity === null) {
        throw new AppError('UNAUTHENTICATED', 'Sign in to continue.');
      }
      await app.tokenVerifier.revokeRefreshTokens(identity.uid);
      return reply.status(204).send(null);
    },
  );
}
