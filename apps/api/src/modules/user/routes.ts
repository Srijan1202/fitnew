/**
 * /v1/user/* — HTTP and Zod only (§8.3). All protected by default-deny.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';

import {
  customTargetsRequestSchema,
  customTargetsResponseSchema,
  dietPreferencesSchema,
  errorEnvelopeSchema,
  goalResponseSchema,
  patchPreferencesRequestSchema,
  patchProfileRequestSchema,
  putDietPreferencesRequestSchema,
  putGoalRequestSchema,
  targetsViewSchema,
  userPreferencesSchema,
  userProfileDetailSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { UserRepository } from './repository.js';
import { messServiceFor } from '../mess/routes.js';
import { UserService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function userRoutes(app: FastifyInstance): Promise<void> {
  const mess = messServiceFor(app.database.db);
  const service = new UserService(new UserRepository(app.database.db), async (ref) => (await mess.messForRef(ref)) !== null);
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const errors = { 401: errorEnvelopeSchema, 404: errorEnvelopeSchema, 422: errorEnvelopeSchema };

  typed.get(
    '/user/profile',
    { schema: { summary: 'Profile', tags: ['user'], security: [{ bearerAuth: [] }], response: { 200: userProfileDetailSchema, ...errors } } },
    async (request) => service.getProfile(requireUserId(request.userId)),
  );

  typed.patch(
    '/user/profile',
    {
      schema: {
        summary: 'Partial profile update; recomputes targets if a formula input changed',
        tags: ['user'],
        security: [{ bearerAuth: [] }],
        body: patchProfileRequestSchema,
        response: { 200: userProfileDetailSchema, ...errors },
      },
    },
    async (request) => service.patchProfile(requireUserId(request.userId), request.body),
  );

  typed.get(
    '/user/goal',
    { schema: { summary: 'Active goal with current targets', tags: ['user'], security: [{ bearerAuth: [] }], response: { 200: goalResponseSchema, ...errors } } },
    async (request) => service.getGoal(requireUserId(request.userId)),
  );

  typed.put(
    '/user/goal',
    {
      schema: {
        summary: 'Replace the active goal; closes the old one and recomputes targets',
        tags: ['user'],
        security: [{ bearerAuth: [] }],
        body: putGoalRequestSchema,
        response: { 200: goalResponseSchema, ...errors },
      },
    },
    async (request) => service.putGoal(requireUserId(request.userId), request.body),
  );

  // Beta 3.2 (ADR-031): the targets in effect, FITOS's suggestion, and the user's own.
  typed.get(
    '/user/targets',
    {
      schema: {
        summary: "Targets in effect, FITOS's suggestion beside them, and the limits for setting your own",
        tags: ['user'],
        security: [{ bearerAuth: [] }],
        response: { 200: targetsViewSchema, ...errors },
      },
    },
    async (request) => service.getTargets(requireUserId(request.userId)),
  );

  typed.put(
    '/user/targets/custom',
    {
      schema: {
        summary: 'Set your own calories and protein; FITOS splits carbs and fat. Kept through weight and profile changes; a goal change resets it.',
        tags: ['user'],
        security: [{ bearerAuth: [] }],
        body: customTargetsRequestSchema,
        response: { 200: customTargetsResponseSchema, 409: errorEnvelopeSchema, ...errors },
      },
    },
    async (request) => service.setCustomTargets(requireUserId(request.userId), request.body),
  );

  typed.delete(
    '/user/targets/custom',
    {
      schema: {
        summary: "Back to FITOS's suggestion",
        tags: ['user'],
        security: [{ bearerAuth: [] }],
        response: { 200: targetsViewSchema, ...errors },
      },
    },
    async (request) => service.resetTargets(requireUserId(request.userId)),
  );

  typed.get(
    '/user/diet-preferences',
    { schema: { summary: 'Diet type, allergies, exclusions', tags: ['user'], security: [{ bearerAuth: [] }], response: { 200: dietPreferencesSchema, ...errors } } },
    async (request) => service.getDiet(requireUserId(request.userId)),
  );

  typed.put(
    '/user/diet-preferences',
    {
      schema: {
        summary: 'Replace diet preferences. Allergies are a hard filter (§9.2); the list sent IS the list.',
        tags: ['user'],
        security: [{ bearerAuth: [] }],
        body: putDietPreferencesRequestSchema,
        response: { 200: dietPreferencesSchema, ...errors },
      },
    },
    async (request) => service.putDiet(requireUserId(request.userId), request.body),
  );

  typed.get(
    '/user/preferences',
    { schema: { summary: 'Units and notification settings', tags: ['user'], security: [{ bearerAuth: [] }], response: { 200: userPreferencesSchema, ...errors } } },
    async (request) => service.getPreferences(requireUserId(request.userId)),
  );

  typed.patch(
    '/user/preferences',
    {
      schema: {
        summary: 'Partial preferences update',
        tags: ['user'],
        security: [{ bearerAuth: [] }],
        body: patchPreferencesRequestSchema,
        response: { 200: userPreferencesSchema, ...errors },
      },
    },
    async (request) => service.patchPreferences(requireUserId(request.userId), request.body),
  );
}
