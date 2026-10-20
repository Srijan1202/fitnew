/**
 * /v1/recovery — the §18 check-in and today's readiness (Phase 13, MASTER-SPEC
 * §10.1, §18; ADR-019). HTTP and Zod only (§8.3). Default-deny like every /v1
 * route. `/recovery/health-sync` is V2 and not built: Health Connect data
 * stays on the phone (ADR-008).
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { errorEnvelopeSchema, logRecoveryRequestSchema, logRecoveryResponseSchema, recoveryTodaySchema } from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { FoodLogRepository } from '../nutrition/log-repository.js';
import { ReadinessAssembler } from './readiness.js';
import { RecoveryRepository } from './repository.js';
import { RecoveryService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function recoveryRoutes(app: FastifyInstance): Promise<void> {
  const db = app.database.db;
  const service = new RecoveryService(new RecoveryRepository(db), ReadinessAssembler.forDb(db), new FoodLogRepository(db));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 422: errorEnvelopeSchema };

  typed.get(
    '/recovery/today',
    {
      schema: {
        summary: "Today's check-in and readiness (Phase 13)",
        description:
          'Readiness (0–100) is computed on read from your check-ins, your training and your food logs, in your stored ' +
          "timezone (§18); it is null until today's check-in exists, and a component without its input adds nothing. " +
          'Advice only: nothing changes your plan.',
        tags: ['recovery'],
        security,
        response: { 200: recoveryTodaySchema, ...errors },
      },
    },
    async (request) => service.today(requireUserId(request.userId)),
  );

  typed.post(
    '/recovery/log',
    {
      schema: {
        summary: 'Check in: sleep, soreness, energy, stress (upsert on date; up to 7 days back, never ahead)',
        description:
          "201 for a new day, 200 when it replaces that day's check-in (the values sent replace the day's). Every value is " +
          'optional but at least one is required.',
        tags: ['recovery'],
        security,
        body: logRecoveryRequestSchema,
        response: { 200: logRecoveryResponseSchema, 201: logRecoveryResponseSchema, ...errors },
      },
    },
    async (request, reply) => {
      const { created, body } = await service.log(requireUserId(request.userId), request.body);
      return reply.code(created ? 201 : 200).send(body);
    },
  );
}
