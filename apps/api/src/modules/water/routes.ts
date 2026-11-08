/**
 * /v1/water — beta 6.0 (F7, ADR-059): the day's water and its target. HTTP
 * and Zod only. Default-deny like every /v1 route; the admin's `water`
 * switch turns it off (403 feature-off).
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { errorEnvelopeSchema, setWaterRequestSchema, waterDateParamsSchema, waterDaySchema } from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { FoodLogRepository } from '../nutrition/log-repository.js';
import { WaterRepository } from './repository.js';
import { WaterService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function waterRoutes(app: FastifyInstance): Promise<void> {
  const db = app.database.db;
  const service = new WaterService(new WaterRepository(db), new FoodLogRepository(db));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 403: errorEnvelopeSchema, 422: errorEnvelopeSchema };
  const on = { preHandler: async (): Promise<void> => app.features.require('water') };

  typed.get(
    '/water/today',
    {
      ...on,
      schema: {
        summary: "Today's water and its target (beta 6.0)",
        description:
          "The day is the stored timezone's. The target is 35 ml a kg of the latest weigh-in, to the nearest 250 ml, " +
          'between 1.5 and 4 L; 2.5 L without a weigh-in.',
        tags: ['water'],
        security,
        response: { 200: waterDaySchema, ...errors },
      },
    },
    async (request) => service.today(requireUserId(request.userId)),
  );

  typed.put(
    '/water/days/:date',
    {
      ...on,
      schema: {
        summary: "Set a day's water total in ml (up to 7 days back, never ahead)",
        description: "Replaces the day's total, so sending the same total again changes nothing. 201 for a new day, 200 when it replaces one.",
        tags: ['water'],
        security,
        params: waterDateParamsSchema,
        body: setWaterRequestSchema,
        response: { 200: waterDaySchema, 201: waterDaySchema, ...errors },
      },
    },
    async (request, reply) => {
      const { created, body } = await service.set(requireUserId(request.userId), request.params.date, request.body.ml);
      return reply.code(created ? 201 : 200).send(body);
    },
  );
}
