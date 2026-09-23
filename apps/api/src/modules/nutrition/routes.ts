/**
 * /v1/nutrition/foods — the food library (Phase 7). HTTP and Zod only (§8.3).
 * Default-deny like every /v1 route. No logging, barcode or AI endpoints here:
 * those belong to Phase 8, V1.5 and Phase 14.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import {
  createFoodRequestSchema,
  errorEnvelopeSchema,
  foodSchema,
  foodSearchQuerySchema,
  foodSearchResponseSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { FoodRepository } from './repository.js';
import { FoodService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function nutritionRoutes(app: FastifyInstance): Promise<void> {
  const service = new FoodService(new FoodRepository(app.database.db));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const errors = { 401: errorEnvelopeSchema, 422: errorEnvelopeSchema };
  const security = [{ bearerAuth: [] }];

  typed.get(
    '/nutrition/foods/search',
    {
      schema: {
        summary: 'Search foods: exact name, then alias, prefix, fuzzy. Global foods plus your own custom foods.',
        tags: ['nutrition'],
        security,
        querystring: foodSearchQuerySchema,
        response: { 200: foodSearchResponseSchema, ...errors },
      },
    },
    async (request) => service.search(requireUserId(request.userId), request.query),
  );

  typed.post(
    '/nutrition/foods',
    {
      schema: {
        summary: 'Create a custom food from a label (retry-safe by clientFoodId; visible only to you)',
        tags: ['nutrition'],
        security,
        body: createFoodRequestSchema,
        response: { 200: foodSchema, 201: foodSchema, ...errors },
      },
    },
    async (request, reply) => {
      const { food, created } = await service.create(requireUserId(request.userId), request.body);
      return reply.code(created ? 201 : 200).send(food);
    },
  );
}
