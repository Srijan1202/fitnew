/**
 * Feedback (Phase 19, ADR-026). `POST /feedback` for any signed-in user, with
 * a per-user hourly limit; the admin list and status change behind the admin
 * claim, checked before validation like every /admin route (Phase 16). An
 * admin sets a status and a triage priority (red, yellow, green).
 *
 * Beta 3.6: pictures with the message (so the body may be up to ~4.5 MB on
 * this route only), the sender's own messages and replies, an admin's
 * reply, the pictures for the admin panel, and a daily clean-up of
 * pictures older than six months.
 */
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import {
  FEEDBACK_PER_HOUR,
  adminFeedbackCountsSchema,
  adminFeedbackItemSchema,
  adminFeedbackListSchema,
  adminFeedbackQuerySchema,
  errorEnvelopeSchema,
  feedbackReplySchema,
  myFeedbackListSchema,
  replyFeedbackRequestSchema,
  sendFeedbackRequestSchema,
  sendFeedbackResponseSchema,
  updateFeedbackRequestSchema,
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
const pictureParams = z.object({ id: z.string().uuid(), pictureId: z.string().uuid() }).strict();

/** Three resized pictures in base64 and the text, with room to spare. */
const SEND_BODY_LIMIT = 4_600_000;
const PURGE_EVERY_MS = 24 * 60 * 60 * 1000;

export async function feedbackRoutes(app: FastifyInstance): Promise<void> {
  const service = new FeedbackService(new FeedbackRepository(app.database.db), app.push);

  // Beta 3.6: pictures older than six months go, at start and once a day.
  const purge = () =>
    service.purgeOldPictures().then(
      (n) => {
        if (n > 0) app.log.info({ pictures: n }, 'feedback: old pictures deleted');
      },
      (e: unknown) => app.log.warn({ err: e }, 'feedback: picture clean-up failed'),
    );
  let timer: NodeJS.Timeout | undefined;
  app.addHook('onReady', async () => {
    void purge();
    timer = setInterval(() => void purge(), PURGE_EVERY_MS);
    timer.unref();
  });
  app.addHook('onClose', async () => clearInterval(timer));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 403: errorEnvelopeSchema, 404: errorEnvelopeSchema, 422: errorEnvelopeSchema, 429: errorEnvelopeSchema };
  const admin = { preValidation: requireAdmin };

  typed.post('/feedback', {
    bodyLimit: SEND_BODY_LIMIT,
    config: {
      rateLimit: {
        max: FEEDBACK_PER_HOUR,
        timeWindow: '1 hour',
        hook: 'preHandler',
        keyGenerator: (request: FastifyRequest): string => (request.userId !== null ? `feedback:${request.userId}` : `feedback-ip:${request.ip}`),
        // The owner and other admins test feedback freely.
        allowList: (request: FastifyRequest): boolean => request.identity?.claims['role'] === 'admin',
      },
    },
    schema: {
      summary: 'Send feedback to the FITOS team: a category, a message, the app version, and (beta 3.6) up to 3 pictures and the phone (§31 Phase 19)',
      tags: ['feedback'],
      security,
      body: sendFeedbackRequestSchema,
      response: { 201: sendFeedbackResponseSchema, ...errors },
    },
  }, async (request, reply) => {
    const created = await service.send(requireUserId(request.userId), request.body);
    return reply.code(201).send(created);
  });

  typed.get('/feedback/mine', {
    schema: {
      summary: "Beta 3.6: the sender's own messages, newest first, with the FITOS team's replies and how many are unread",
      tags: ['feedback'],
      security,
      response: { 200: myFeedbackListSchema, ...errors },
    },
  }, async (request) => service.mine(requireUserId(request.userId)));

  typed.post('/feedback/mine/read', {
    schema: {
      summary: 'Beta 3.6: every reply to the sender is now read',
      tags: ['feedback'],
      security,
      response: { 200: z.object({ unread: z.literal(0) }).strict(), ...errors },
    },
  }, async (request) => service.markRead(requireUserId(request.userId)));

  typed.get('/admin/feedback', {
    ...admin,
    schema: {
      summary: 'Feedback from the app, newest first, by status (or open: not done) and tag; the sender as an id only',
      tags: ['admin'],
      security,
      querystring: adminFeedbackQuerySchema,
      response: { 200: adminFeedbackListSchema, ...errors },
    },
  }, async (request) => service.page(request.query.status, request.query.priority, request.query.category, request.query.limit, request.query.before));

  typed.get('/admin/feedback/:id/pictures/:pictureId', {
    ...admin,
    schema: {
      summary: 'Beta 3.6: one picture sent with feedback (JPEG, PNG or WebP), for the admin panel; never cached',
      tags: ['admin'],
      security,
      params: pictureParams,
      // The bytes go out as they are (Fastify never serializes a Buffer).
      response: { 200: z.unknown().describe('The image bytes'), ...errors },
    },
  }, async (request, reply) => {
    const p = await service.picture(request.params.id, request.params.pictureId);
    return reply.type(p.type).header('cache-control', 'private, no-store').send(p.data);
  });

  typed.post('/admin/feedback/:id/replies', {
    ...admin,
    schema: {
      summary: "Beta 3.6: reply to feedback; the sender reads it in the app and is told by a notification; audited",
      tags: ['admin'],
      security,
      params: idParams,
      body: replyFeedbackRequestSchema,
      response: { 201: feedbackReplySchema, ...errors },
    },
  }, async (request, reply) => {
    const r = await service.reply(request.userId, request.params.id, request.body.message);
    return reply.code(201).send(r.reply);
  });

  typed.get('/admin/feedback/counts', {
    ...admin,
    schema: {
      summary: 'How much feedback is waiting: open and not tagged, open per tag (red, yellow, green), and done',
      tags: ['admin'],
      security,
      response: { 200: adminFeedbackCountsSchema, ...errors },
    },
  }, async () => service.counts());

  typed.patch('/admin/feedback/:id', {
    ...admin,
    schema: {
      summary: 'Mark feedback new, read or done, and/or tag it red, yellow or green (null clears); each change audited',
      tags: ['admin'],
      security,
      params: idParams,
      body: updateFeedbackRequestSchema,
      response: { 200: adminFeedbackItemSchema, ...errors },
    },
  }, async (request) => service.update(request.userId, request.params.id, request.body));
}
