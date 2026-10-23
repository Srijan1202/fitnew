/**
 * Premium (Phase 19, ADR-027). For the user: GET /premium, POST
 * /premium/request, PUT /user/avatar. For the admin (claim checked before
 * validation, every decision audited): the requests, the decision, the
 * members and revoking.
 */
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import {
  adminPremiumMemberListSchema,
  adminPremiumQuerySchema,
  adminPremiumRequestListSchema,
  avatarResponseSchema,
  rewardsResponseSchema,
  decidePremiumRequestSchema,
  errorEnvelopeSchema,
  premiumRequestSchema,
  premiumStatusSchema,
  requestPremiumSchema,
  setAvatarRequestSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { requireAdmin } from '../../plugins/auth.js';
import { PremiumRepository } from './repository.js';
import { PremiumService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

/** Five requests a day per user: a denial can be answered, a flood cannot. */
export const PREMIUM_REQUESTS_PER_DAY = 5;

const idParams = z.object({ id: z.string().uuid() }).strict();
const userParams = z.object({ userId: z.string().uuid() }).strict();

export async function premiumRoutes(app: FastifyInstance): Promise<void> {
  const service = new PremiumService(new PremiumRepository(app.database.db));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 403: errorEnvelopeSchema, 404: errorEnvelopeSchema, 409: errorEnvelopeSchema, 422: errorEnvelopeSchema, 429: errorEnvelopeSchema };
  const admin = { preValidation: requireAdmin };
  const tags = ['premium'];

  typed.get('/premium', {
    schema: { summary: 'Am I premium, and where is my request?', tags, security, response: { 200: premiumStatusSchema, ...errors } },
  }, async (request) => service.status(requireUserId(request.userId), request.identity?.claims));

  typed.post('/premium/request', {
    config: {
      rateLimit: {
        max: PREMIUM_REQUESTS_PER_DAY,
        timeWindow: '1 day',
        hook: 'preHandler',
        keyGenerator: (request: FastifyRequest): string => (request.userId !== null ? `premium:${request.userId}` : `premium-ip:${request.ip}`),
      },
    },
    schema: { summary: 'Ask for FITOS Premium (the owner approves it in the admin panel)', tags, security, body: requestPremiumSchema, response: { 201: premiumRequestSchema, ...errors } },
  }, async (request, reply) => {
    const r = await service.request(requireUserId(request.userId), request.identity?.claims, request.body.message);
    return reply.code(201).send(r);
  });

  typed.get('/user/rewards', {
    schema: {
      summary: 'Streak rewards you earned, kept forever (beta 3.4)',
      tags: ['premium'],
      security,
      response: { 200: rewardsResponseSchema, ...errors },
    },
  }, async (request) => service.rewards(requireUserId(request.userId)));

  typed.put('/user/avatar', {
    schema: {
      summary: 'Choose a profile picture (three are premium) or none',
      tags: ['user'],
      security,
      body: setAvatarRequestSchema,
      response: { 200: avatarResponseSchema, ...errors },
    },
  }, async (request) => service.setAvatar(requireUserId(request.userId), request.identity?.claims, request.body.avatarId));

  /* -------------------------------------------------------------- admin -- */

  typed.get('/admin/premium/requests', {
    ...admin,
    schema: { summary: 'Premium requests, newest first, with who asked', tags: ['admin'], security, querystring: adminPremiumQuerySchema, response: { 200: adminPremiumRequestListSchema, ...errors } },
  }, async (request) => service.requests(request.query.status, request.query.limit));

  typed.post('/admin/premium/requests/:id/decision', {
    ...admin,
    schema: {
      summary: 'Approve (premium until revoked) or deny a pending request, with an optional note (audited)',
      tags: ['admin'],
      security,
      params: idParams,
      body: decidePremiumRequestSchema,
      response: { 200: premiumRequestSchema, ...errors },
    },
  }, async (request) => service.decide(request.userId, request.params.id, request.body.decision, request.body.note));

  typed.get('/admin/premium/members', {
    ...admin,
    schema: { summary: 'Who has premium (by approval; admins have it by role)', tags: ['admin'], security, response: { 200: adminPremiumMemberListSchema, ...errors } },
  }, async () => service.members());

  typed.post('/admin/premium/members/:userId/revoke', {
    ...admin,
    schema: { summary: 'Take premium away (a premium picture goes back to none; audited)', tags: ['admin'], security, params: userParams, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.revoke(request.userId, request.params.userId);
    return reply.code(204).send(null);
  });
}
