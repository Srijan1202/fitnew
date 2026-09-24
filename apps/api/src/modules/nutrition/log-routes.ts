/**
 * /v1/nutrition — food logging (Phase 8). HTTP and Zod only (§8.3).
 * Default-deny like every /v1 route. No AI or barcode endpoints here; mess
 * dishes are logged here too (Phase 9, entryMethod `mess`).
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';

import {
  clientLogIdParamsSchema,
  createLogRequestSchema,
  createLogResponseSchema,
  createSavedMealRequestSchema,
  deleteLogResponseSchema,
  errorEnvelopeSchema,
  nutritionDayParamsSchema,
  nutritionDaySchema,
  recentFoodsQuerySchema,
  recentFoodsResponseSchema,
  savedMealIdParamsSchema,
  savedMealSchema,
  savedMealsResponseSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { FoodLogRepository } from './log-repository.js';
import { FoodLogService } from './log-service.js';
import { FoodRepository } from './repository.js';
import { messServiceFor } from '../mess/routes.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function foodLogRoutes(app: FastifyInstance): Promise<void> {
  const service = new FoodLogService(
    new FoodLogRepository(app.database.db),
    new FoodRepository(app.database.db),
    undefined,
    messServiceFor(app.database.db),
  );
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 404: errorEnvelopeSchema, 422: errorEnvelopeSchema };

  typed.get(
    '/nutrition/today',
    {
      schema: {
        summary: "Today in your zone: the target in effect, what you logged, totals and what remains (ranges)",
        tags: ['nutrition'],
        security,
        response: { 200: nutritionDaySchema, ...errors },
      },
    },
    async (request) => service.today(requireUserId(request.userId)),
  );

  typed.get(
    '/nutrition/day/:date',
    {
      schema: {
        summary: 'A past day (yyyy-mm-dd, your zone) with the target that was in effect then; a future day is 422',
        tags: ['nutrition'],
        security,
        params: nutritionDayParamsSchema,
        response: { 200: nutritionDaySchema, ...errors },
      },
    },
    async (request) => service.day(requireUserId(request.userId), request.params.date),
  );

  typed.post(
    '/nutrition/logs',
    {
      schema: {
        summary: 'Log food, quick add or a saved meal. Nutrition is snapshotted now. Retry-safe by clientLogId (201, then 200)',
        tags: ['nutrition'],
        security,
        body: createLogRequestSchema,
        response: { 200: createLogResponseSchema, 201: createLogResponseSchema, ...errors },
      },
    },
    async (request, reply) => {
      const { created, ...result } = await service.create(requireUserId(request.userId), request.body);
      return reply.code(created ? 201 : 200).send(result);
    },
  );

  typed.delete(
    '/nutrition/logs/:clientLogId',
    {
      schema: {
        summary: "Delete a whole log by its clientLogId (idempotent); returns the log's day",
        tags: ['nutrition'],
        security,
        params: clientLogIdParamsSchema,
        response: { 200: deleteLogResponseSchema, ...errors },
      },
    },
    async (request) => service.remove(requireUserId(request.userId), request.params.clientLogId),
  );

  typed.get(
    '/nutrition/foods/recent',
    {
      schema: {
        summary: 'Foods you logged most recently, newest first, with the portion you used last',
        tags: ['nutrition'],
        security,
        querystring: recentFoodsQuerySchema,
        response: { 200: recentFoodsResponseSchema, ...errors },
      },
    },
    async (request) => service.recent(requireUserId(request.userId), request.query.limit),
  );

  typed.get(
    '/nutrition/saved-meals',
    {
      schema: {
        summary: 'Your saved meals',
        tags: ['nutrition'],
        security,
        response: { 200: savedMealsResponseSchema, ...errors },
      },
    },
    async (request) => service.savedMeals(requireUserId(request.userId)),
  );

  typed.post(
    '/nutrition/saved-meals',
    {
      schema: {
        summary: 'Save logged meals as one meal (from logs only; retry-safe by clientMealId)',
        tags: ['nutrition'],
        security,
        body: createSavedMealRequestSchema,
        response: { 200: savedMealSchema, 201: savedMealSchema, ...errors },
      },
    },
    async (request, reply) => {
      const { meal, created } = await service.createSavedMeal(requireUserId(request.userId), request.body);
      return reply.code(created ? 201 : 200).send(meal);
    },
  );

  typed.delete(
    '/nutrition/saved-meals/:id',
    {
      schema: {
        summary: 'Delete a saved meal (logs made from it keep their items)',
        tags: ['nutrition'],
        security,
        params: savedMealIdParamsSchema,
        response: { 204: z.null(), ...errors },
      },
    },
    async (request, reply) => {
      await service.deleteSavedMeal(requireUserId(request.userId), request.params.id);
      return reply.code(204).send(null);
    },
  );
}
