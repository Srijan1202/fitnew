/**
 * /v1/progress — the PROGRESS summary and the two readings the spec names
 * (Phase 12, MASTER-SPEC §10.1, §17; ADR-018). HTTP and Zod only (§8.3).
 * Default-deny like every /v1 route. Photos are deferred (owner D3); there is
 * no /recovery route (Phase 13).
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import {
  errorEnvelopeSchema,
  logMeasurementRequestSchema,
  logMeasurementResponseSchema,
  logWeightRequestSchema,
  logWeightResponseSchema,
  progressSummaryQuerySchema,
  progressSummarySchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { FoodLogRepository } from '../nutrition/log-repository.js';
import { ProgressRepository } from './repository.js';
import { ProgressService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function progressRoutes(app: FastifyInstance): Promise<void> {
  const service = new ProgressService(new ProgressRepository(app.database.db), new FoodLogRepository(app.database.db));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 422: errorEnvelopeSchema };

  typed.get(
    '/progress/summary',
    {
      schema: {
        summary: 'Progress over 30 or 90 days: trend weight, measurements, records, adherence, consistency (Phase 12)',
        description:
          'Computed on read from your own records in your stored timezone; nothing derived is stored. The trend weight is ' +
          'the headline (EWMA); the weekly rate is null before 10 days of data; every change covers at least 7 days — ' +
          'there is no day-over-day figure. Adherence counts only days with a log.',
        tags: ['progress'],
        security,
        querystring: progressSummaryQuerySchema,
        response: { 200: progressSummarySchema, ...errors },
      },
    },
    async (request) => service.summary(requireUserId(request.userId), request.query.window),
  );

  typed.post(
    '/progress/weight',
    {
      schema: {
        summary: 'Log a weight for a local day (upsert on date; up to 30 days back, never ahead)',
        description: '201 for a new day, 200 when it replaces that day\'s reading. Never recalculates the nutrition targets.',
        tags: ['progress'],
        security,
        body: logWeightRequestSchema,
        response: { 200: logWeightResponseSchema, 201: logWeightResponseSchema, ...errors },
      },
    },
    async (request, reply) => {
      const { created, body } = await service.logWeight(requireUserId(request.userId), request.body);
      return reply.code(created ? 201 : 200).send(body);
    },
  );

  typed.post(
    '/progress/measurement',
    {
      schema: {
        summary: 'Log a tape measurement for a local day and site (upsert; up to 30 days back, never ahead)',
        description: '201 for a new day and site, 200 when it replaces that reading.',
        tags: ['progress'],
        security,
        body: logMeasurementRequestSchema,
        response: { 200: logMeasurementResponseSchema, 201: logMeasurementResponseSchema, ...errors },
      },
    },
    async (request, reply) => {
      const { created, body } = await service.logMeasurement(requireUserId(request.userId), request.body);
      return reply.code(created ? 201 : 200).send(body);
    },
  );
}
