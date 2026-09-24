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
          'Order: an exact replay of a stored `clientEventId` (same action, event and occurredAt) is 200 with the stored event, ' +
          'even after the timing window; the same `clientEventId` for a different action, event or occurredAt is 409. Then: ' +
          "another user's or an unknown action is 404; a new event outside its action's window (5-minute skew, the local day " +
          'through 03:00 the next, delivered within 7 days) is 422; an impossible transition is 422 (a repeat of an event already ' +
          'recorded is 200 with it); `completed` without evidence on record is 422; otherwise 201.',
        tags: ['today'],
        security,
        params: todayActionParamsSchema,
        body: todayEventRequestSchema,
        response: { 200: todayEventResponseSchema, 201: todayEventResponseSchema, 409: errorEnvelopeSchema, ...errors },
      },
    },
    async (request, reply) => {
      const { created, event } = await service.recordEvent(requireUserId(request.userId), request.params.id, request.body);
      return reply.code(created ? 201 : 200).send({ event });
    },
  );
}
