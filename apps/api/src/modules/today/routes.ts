/**
 * /v1/today — TODAY's ranked actions and how the user responded (Phase 11,
 * ADR-017; MASTER-SPEC §16, §9.2). HTTP and Zod only (§8.3). Default-deny
 * like every /v1 route. Deterministic core engine; never an LLM (D14).
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import {
  errorEnvelopeSchema,
  todayActionParamsSchema,
  todayActionsResponseSchema,
  todayEventRequestSchema,
  todayEventResponseSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { RecommendRepository } from '../mess/recommend-repository.js';
import { FoodLogRepository } from '../nutrition/log-repository.js';
import { TrainingRepository } from '../training/repository.js';
import { WorkoutRepository } from '../workout/repository.js';
import { WorkoutService } from '../workout/service.js';
import { TodayRepository } from './repository.js';
import { TodayService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function todayRoutes(app: FastifyInstance): Promise<void> {
  const db = app.database.db;
  const training = new TrainingRepository(db);
  const service = new TodayService(
    new TodayRepository(db),
    new WorkoutService(new WorkoutRepository(db), training),
    training,
    new FoodLogRepository(db),
    new RecommendRepository(db),
  );
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 404: errorEnvelopeSchema, 422: errorEnvelopeSchema };

  typed.get(
    '/today',
    {
      schema: {
        summary: 'TODAY: up to 4 ranked actions for your local day (Phase 11)',
        description:
          'Decided on the server by the deterministic engine from your plan, logs, targets and body records, in your stored ' +
          'timezone. Each action carries a structured reason (code + values, the source of truth) and deterministic English. ' +
          'An action keeps its id while its content is unchanged; `rank` is the current rank. Actions dismissed today are omitted.',
        tags: ['today'],
        security,
        response: { 200: todayActionsResponseSchema, 401: errorEnvelopeSchema },
      },
    },
    async (request) => service.today(requireUserId(request.userId)),
  );

  typed.post(
    '/today/actions/:id/event',
    {
      schema: {
        summary: 'Record how you responded to a TODAY action: shown, opened, accepted, dismissed or completed',
        description:
          'Idempotent per `clientEventId` (201 when stored, 200 on a replay). Each event is recorded once per action; a repeat ' +
          'returns 200 with the stored one. Impossible transitions, `completed` without evidence on record, and times outside ' +
          'the action\'s day (through 03:00 the next local day, delivered within 7 days) are 422. Another user\'s action is 404.',
        tags: ['today'],
        security,
        params: todayActionParamsSchema,
        body: todayEventRequestSchema,
        response: { 200: todayEventResponseSchema, 201: todayEventResponseSchema, ...errors },
      },
    },
    async (request, reply) => {
      const { created, event } = await service.recordEvent(requireUserId(request.userId), request.params.id, request.body);
      return reply.code(created ? 201 : 200).send({ event });
    },
  );
}
