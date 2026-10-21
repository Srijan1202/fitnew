/**
 * /v1/admin/* — Phase 16 (MASTER-SPEC §20, §10.1; ADR-022). Every route runs
 * `requireAdmin` (the Firebase custom claim `role: admin`, on the server,
 * every request: 401 without a session, 403 without the claim). Every change
 * writes `audit_logs`. Also GET /meta/config, public (§10.1).
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import {
  adminDishParamsSchema,
  adminExerciseListSchema,
  adminExerciseQuerySchema,
  adminExerciseSchema,
  adminFoodListSchema,
  adminFoodQuerySchema,
  adminFoodSchema,
  adminMeSchema,
  adminOverviewQuerySchema,
  adminOverviewSchema,
  auditListSchema,
  auditQuerySchema,
  correctionGroupSchema,
  correctionQueueQuerySchema,
  correctionQueueSchema,
  dishDietRequestSchema,
  editDishEstimateRequestSchema,
  editExerciseRequestSchema,
  editFoodRequestSchema,
  endpointHealthSchema,
  errorEnvelopeSchema,
  exerciseInputSchema,
  featureFlagListSchema,
  featureFlagSchema,
  flagParamsSchema,
  metaConfigSchema,
  putFlagRequestSchema,
  reviewCorrectionRequestSchema,
  userLookupQuerySchema,
  userSupportSchema,
} from '@fitos/contracts';

import { requireAdmin } from '../../plugins/auth.js';
import { TrainingRepository } from '../training/repository.js';
import { AdminRepository } from './repository.js';
import { AdminService } from './service.js';

const idParams = z.object({ id: z.string().uuid() }).strict();

export async function adminRoutes(app: FastifyInstance): Promise<void> {
  const db = app.database.db;
  const service = new AdminService(new AdminRepository(db), new TrainingRepository(db));
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 403: errorEnvelopeSchema, 404: errorEnvelopeSchema, 409: errorEnvelopeSchema, 422: errorEnvelopeSchema };
  // Before validation: a non-admin learns 403, never the shape of a body (422).
  const admin = { preValidation: requireAdmin };
  const tags = ['admin'];

  // §10.1: unauthenticated, so the app can read it before sign-in.
  typed.get('/meta/config', {
    config: { public: true },
    schema: {
      summary: 'What the app may switch on: the feature flags (public, §10.1)',
      tags: ['meta'],
      response: { 200: metaConfigSchema },
    },
  }, async () => service.metaConfig());

  typed.get('/admin/me', { ...admin, schema: { summary: 'Am I an administrator? (403 if not)', tags, security, response: { 200: adminMeSchema, ...errors } } }, async (request) => ({
    userId: request.userId,
    email: request.identity?.email ?? null,
    isAdmin: true as const,
  }));

  typed.get('/admin/overview', {
    ...admin,
    schema: { summary: 'Provider health, pending corrections, users, recommendation and reminder rates', tags, security, querystring: adminOverviewQuerySchema, response: { 200: adminOverviewSchema, ...errors } },
  }, async (request) => service.overview(request.query.days));

  typed.get('/admin/mess/health', {
    ...admin,
    schema: { summary: 'Per-endpoint mirror health and staleness (§20)', tags, security, response: { 200: z.object({ items: z.array(endpointHealthSchema) }).strict(), ...errors } },
  }, async () => ({ items: await service.endpoints() }));

  /* -------------------------------------------------------- corrections -- */

  typed.get('/admin/mess/corrections', {
    ...admin,
    schema: { summary: 'The correction queue, grouped by dish slug', tags, security, querystring: correctionQueueQuerySchema, response: { 200: correctionQueueSchema, ...errors } },
  }, async (request) => ({ items: await service.queue(request.query.status) }));

  typed.post('/admin/mess/corrections/:id/review', {
    ...admin,
    schema: {
      summary: 'Accept (applies to the dish by slug, for every future menu) or reject a correction',
      tags,
      security,
      params: idParams,
      body: reviewCorrectionRequestSchema,
      response: { 200: correctionGroupSchema, ...errors },
    },
  }, async (request) => service.review(request.userId, request.params.id, request.body));

  typed.put('/admin/mess/dishes/:slug/estimate', {
    ...admin,
    schema: { summary: "Set one field of a dish's estimate (with its provenance)", tags, security, params: adminDishParamsSchema, body: editDishEstimateRequestSchema, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    const b = request.body;
    await service.editDish(request.userId, request.params.slug, b.field, b.low, b.high, b.reason);
    return reply.code(204).send(null);
  });

  typed.put('/admin/mess/dishes/:slug/diet', {
    ...admin,
    schema: { summary: "Set (or clear, with null) a dish's diet class by slug", tags, security, params: adminDishParamsSchema, body: dishDietRequestSchema, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.dishDiet(request.userId, request.params.slug, request.body.diet, request.body.reason);
    return reply.code(204).send(null);
  });

  /* -------------------------------------------------------------- foods -- */

  typed.get('/admin/foods', {
    ...admin,
    schema: { summary: 'FITOS foods (never anyone’s custom foods)', tags, security, querystring: adminFoodQuerySchema, response: { 200: adminFoodListSchema, ...errors } },
  }, async (request) => ({ items: await service.foods(request.query.q) }));

  typed.get('/admin/foods/:id', {
    ...admin,
    schema: { summary: 'One FITOS food with its rows and aliases', tags, security, params: idParams, response: { 200: adminFoodSchema, ...errors } },
  }, async (request) => service.food(request.params.id));

  typed.put('/admin/foods/:id', {
    ...admin,
    schema: { summary: 'Correct a FITOS food; the seed leaves it alone from then on', tags, security, params: idParams, body: editFoodRequestSchema, response: { 200: adminFoodSchema, ...errors } },
  }, async (request) => service.editFood(request.userId, request.params.id, request.body));

  /* ---------------------------------------------------------- exercises -- */

  typed.get('/admin/exercises', {
    ...admin,
    schema: { summary: 'The exercise library (retired=true for retired ones)', tags, security, querystring: adminExerciseQuerySchema, response: { 200: adminExerciseListSchema, ...errors } },
  }, async (request) => ({ items: await service.exercises(request.query.q, request.query.retired) }));

  typed.get('/admin/exercises/:id', {
    ...admin,
    schema: { summary: 'One exercise as the editor shows it', tags, security, params: idParams, response: { 200: adminExerciseSchema, ...errors } },
  }, async (request) => service.exercise(request.params.id));

  typed.post('/admin/exercises', {
    ...admin,
    schema: { summary: 'Create an exercise', tags, security, body: exerciseInputSchema, response: { 201: adminExerciseSchema, ...errors } },
  }, async (request, reply) => reply.code(201).send(await service.createExercise(request.userId, request.body)));

  typed.put('/admin/exercises/:id', {
    ...admin,
    schema: { summary: 'Edit an exercise (alternatives are kept)', tags, security, params: idParams, body: editExerciseRequestSchema, response: { 200: adminExerciseSchema, ...errors } },
  }, async (request) => service.editExercise(request.userId, request.params.id, request.body));

  typed.post('/admin/exercises/:id/retire', {
    ...admin,
    schema: { summary: 'Retire: out of the browser and new programmes; history keeps it', tags, security, params: idParams, response: { 200: adminExerciseSchema, ...errors } },
  }, async (request) => service.retireExercise(request.userId, request.params.id, true));

  typed.post('/admin/exercises/:id/restore', {
    ...admin,
    schema: { summary: 'Bring a retired exercise back', tags, security, params: idParams, response: { 200: adminExerciseSchema, ...errors } },
  }, async (request) => service.retireExercise(request.userId, request.params.id, false));

  /* -------------------------------------------------------------- flags -- */

  typed.get('/admin/flags', {
    ...admin,
    schema: { summary: 'Feature flags', tags, security, response: { 200: featureFlagListSchema, ...errors } },
  }, async () => ({ items: await service.flags() }));

  typed.put('/admin/flags/:key', {
    ...admin,
    schema: { summary: 'Create or change a feature flag', tags, security, params: flagParamsSchema, body: putFlagRequestSchema, response: { 200: featureFlagSchema, ...errors } },
  }, async (request) => service.putFlag(request.userId, request.params.key, request.body.enabled, request.body.description));

  /* ------------------------------------------------------------ support -- */

  typed.get('/admin/users', {
    ...admin,
    schema: {
      summary: 'Support lookup by email or id: counts and dates only — no photos, no food log contents (§20). Audited.',
      tags,
      security,
      querystring: userLookupQuerySchema,
      response: { 200: userSupportSchema, ...errors },
    },
  }, async (request) => service.lookupUser(request.userId, request.query));

  typed.get('/admin/audit', {
    ...admin,
    schema: { summary: 'The audit log, newest first', tags, security, querystring: auditQuerySchema, response: { 200: auditListSchema, ...errors } },
  }, async (request) => service.auditPage(request.query.limit, request.query.before));
}
