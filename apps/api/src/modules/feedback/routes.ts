/**
 * Feedback (Phase 19, ADR-026). `POST /feedback` for any signed-in user, with
 * a per-user hourly limit; the admin list and status change behind the admin
 * claim, checked before validation like every /admin route (Phase 16).
 */
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import {
  FEEDBACK_PER_HOUR,
  adminFeedbackItemSchema,
  adminFeedbackListSchema,
  adminFeedbackQuerySchema,
  errorEnvelopeSchema,
  sendFeedbackRequestSchema,
  sendFeedbackResponseSchema,
  setFeedbackStatusRequestSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { requireAdmin } from '../../plugins/auth.js';
import { FeedbackRepository } from './repository.js';
import { FeedbackService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

const idParams = z.object({ id: z.string().uuid() }).strict();

export async function feedbackRoutes(app: FastifyInstance): Promise<void> {
  const service = new FeedbackService(new FeedbackRepository(app.database.db));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 403: errorEnvelopeSchema, 404: errorEnvelopeSchema, 422: errorEnvelopeSchema, 429: errorEnvelopeSchema };
  const admin = { preValidation: requireAdmin };

  typed.post('/feedback', {
    config: {
      rateLimit: {
        max: FEEDBACK_PER_HOUR,
        timeWindow: '1 hour',
        hook: 'preHandler',
        keyGenerator: (request: FastifyRequest): string => (request.userId !== null ? `feedback:${request.userId}` : `feedback-ip:${request.ip}`),
      },
    },
    schema: {
      summary: 'Send feedback to the FITOS team: a category, a message and the app version (§31 Phase 19)',
      tags: ['feedback'],
      security,
      body: sendFeedbackRequestSchema,
      response: { 201: sendFeedbackResponseSchema, ...errors },
    },
  }, async (request, reply) => {
    const created = await service.send(requireUserId(request.userId), request.body);
    return reply.code(201).send(created);
  });

  typed.get('/admin/feedback', {
    ...admin,
    schema: {
      summary: 'Feedback from the app, newest first; the sender as an id only',
      tags: ['admin'],
      security,
      querystring: adminFeedbackQuerySchema,
      response: { 200: adminFeedbackListSchema, ...errors },
    },
  }, async (request) => service.page(request.query.status, request.query.limit, request.query.before));

  typed.patch('/admin/feedback/:id', {
    ...admin,
    schema: {
      summary: 'Mark feedback new, read or done (audited)',
      tags: ['admin'],
      security,
      params: idParams,
      body: setFeedbackStatusRequestSchema,
      response: { 200: adminFeedbackItemSchema, ...errors },
    },
  }, async (request) => service.setStatus(request.userId, request.params.id, request.body.status));
}
