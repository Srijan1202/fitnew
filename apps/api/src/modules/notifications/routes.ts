/**
 * /v1/notifications — Phase 15 (MASTER-SPEC §21, §10.1; ADR-021). The server
 * plans, the phone schedules: settings, the plan (with the phone's reports
 * on earlier ones), a preview for the settings screen, and FCM token
 * registration. Default-deny like every /v1 route.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import {
  errorEnvelopeSchema,
  notifyPlanRequestSchema,
  notifyPlanResponseSchema,
  notifyPreviewRequestSchema,
  notifyPreviewResponseSchema,
  notifySettingsPatchSchema,
  notifySettingsSchema,
  pushTokenRequestSchema,
} from '@fitos/contracts';
import { z } from 'zod';

import { AppError } from '../../lib/errors.js';
import { RecommendRepository } from '../mess/recommend-repository.js';
import { MessRecommendService } from '../mess/recommend-service.js';
import { messServiceFor } from '../mess/routes.js';
import { FoodLogRepository } from '../nutrition/log-repository.js';
import { ReadinessAssembler } from '../recovery/readiness.js';
import { PlanRepository } from '../running/plan-repository.js';
import { TrainingRepository } from '../training/repository.js';
import { UserRepository } from '../user/repository.js';
import { NotificationRepository } from './repository.js';
import { NotificationService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function notificationRoutes(app: FastifyInstance): Promise<void> {
  const db = app.database.db;
  // Beta 6.1 (E17): the protein nudge names tonight's dish from the published mess menu.
  const menus = new MessRecommendService(messServiceFor(db, app.features), new UserRepository(db), new FoodLogRepository(db), new RecommendRepository(db));
  const service = new NotificationService(
    new NotificationRepository(db),
    new TrainingRepository(db),
    new FoodLogRepository(db),
    ReadinessAssembler.forDb(db),
    new PlanRepository(db),
    undefined,
    (userId, dates) => menus.dinnerDishes(userId, dates),
  );
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 422: errorEnvelopeSchema };

  typed.get(
    '/notifications/settings',
    {
      schema: {
        summary: 'Notification settings: on/off, tone, each kind, quiet hours (Phase 15)',
        tags: ['notifications'],
        security,
        response: { 200: notifySettingsSchema, ...errors },
      },
    },
    async (request) => service.settings(requireUserId(request.userId)),
  );

  typed.patch(
    '/notifications/settings',
    {
      schema: {
        summary: 'Change any notification setting; returns them all',
        tags: ['notifications'],
        security,
        body: notifySettingsPatchSchema,
        response: { 200: notifySettingsSchema, ...errors },
      },
    },
    async (request) => service.updateSettings(requireUserId(request.userId), request.body),
  );

  typed.post(
    '/notifications/plan',
    {
      schema: {
        summary: "The next days' notifications for the phone to schedule; takes its reports on earlier ones",
        description:
          'Planned from your own records in your stored timezone (§21): at most 4 a day, 2 hours apart, outside quiet hours, ' +
          'timed from your habits, every kind switchable. Each item says what cancels it on the phone (`cancelOn`). ' +
          'The words are FITOS templates, never generated. Reports are replay-safe.',
        tags: ['notifications'],
        security,
        body: notifyPlanRequestSchema,
        response: { 200: notifyPlanResponseSchema, ...errors },
      },
    },
    async (request) => service.plan(requireUserId(request.userId), request.body),
  );

  typed.post(
    '/notifications/preview',
    {
      schema: {
        summary: 'What one kind would say now, in your tone (the settings "try it"); nothing stored',
        tags: ['notifications'],
        security,
        body: notifyPreviewRequestSchema,
        response: { 200: notifyPreviewResponseSchema, ...errors },
      },
    },
    async (request) => service.preview(requireUserId(request.userId), request.body.kind),
  );

  typed.post(
    '/notifications/token',
    {
      schema: {
        summary: 'Register this device for push (FCM). Stored for server push after hosting; nothing is pushed yet',
        tags: ['notifications'],
        security,
        body: pushTokenRequestSchema,
        response: { 204: z.null(), ...errors },
      },
    },
    async (request, reply) => {
      await service.registerToken(requireUserId(request.userId), request.body.token);
      return reply.code(204).send(null);
    },
  );
}
