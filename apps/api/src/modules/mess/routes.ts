/**
 * /v1/mess — VIT mess menus (Phase 9, §31). HTTP and Zod only (§8.3).
 * Default-deny like every /v1 route. Menus come from the server's mirror,
 * never live from MessIT. Phase 10 adds `/mess/menu/recommend`; there are no
 * general (non-mess) recommendations.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { eq } from 'drizzle-orm';
import {
  dishSlugParamsSchema,
  errorEnvelopeSchema,
  messCorrectionRequestSchema,
  messCorrectionSchema,
  messMenuQuerySchema,
  messMenuSchema,
  messRecommendQuerySchema,
  messRecommendationSchema,
  messProvidersResponseSchema,
  messesResponseSchema,
  providerSlugParamsSchema,
  type MessRef,
} from '@fitos/contracts';

import type { DatabaseHandle } from '../../db/client.js';
import { userProfiles } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import { FoodLogRepository } from '../nutrition/log-repository.js';
import { UserRepository } from '../user/repository.js';
import { RecommendRepository } from './recommend-repository.js';
import { MessRecommendService } from './recommend-service.js';
import { MessRepository } from './repository.js';
import { MessService } from './service.js';

/** Corrections are rare by nature; a tighter budget than the default 120/min. */
export const CORRECTION_RATE_LIMIT = { max: 20, timeWindow: '1 hour' } as const;

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

/** The user's configured mess (profile), or null. */
export function configuredMessOf(db: DatabaseHandle['db']) {
  return async (userId: string): Promise<MessRef | null> => {
    const [p] = await db
      .select({ providerId: userProfiles.messProviderId, hostelId: userProfiles.messHostelId, messId: userProfiles.messMessId })
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);
    if (p === undefined || p.providerId === null || p.hostelId === null || p.messId === null) return null;
    return { providerId: p.providerId, hostelId: p.hostelId, messId: p.messId };
  };
}

export function messServiceFor(db: DatabaseHandle['db']): MessService {
  const logs = new FoodLogRepository(db);
  return new MessService(new MessRepository(db), (id) => logs.timezoneOf(id), configuredMessOf(db));
}

export async function messRoutes(app: FastifyInstance): Promise<void> {
  const service = messServiceFor(app.database.db);
  const recommend = new MessRecommendService(
    service,
    new UserRepository(app.database.db),
    new FoodLogRepository(app.database.db),
    new RecommendRepository(app.database.db),
  );
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 404: errorEnvelopeSchema, 422: errorEnvelopeSchema };

  typed.get(
    '/mess/providers',
    {
      schema: {
        summary: 'Mess menu providers (VIT Vellore)',
        tags: ['mess'],
        security,
        response: { 200: messProvidersResponseSchema, ...errors },
      },
    },
    async (request) => {
      requireUserId(request.userId);
      return service.providers();
    },
  );

  typed.get(
    '/mess/providers/:slug/messes',
    {
      schema: {
        summary: "A provider's messes, each with how fresh the server's copy of its menu is",
        tags: ['mess'],
        security,
        params: providerSlugParamsSchema,
        response: { 200: messesResponseSchema, ...errors },
      },
    },
    async (request) => {
      requireUserId(request.userId);
      return service.messes(request.params.slug);
    },
  );

  typed.get(
    '/mess/menu',
    {
      schema: {
        summary: 'A mess menu for a day (default: today, your mess): published, inferred from the cycle, or unavailable',
        description:
          'Served from the server\'s mirror of MessIT, never live. `resolution` says whether the mess published this date; ' +
          '`mess.freshness` says when the server last fetched it. Each dish carries its stored estimate (a range) or null.',
        tags: ['mess'],
        security,
        querystring: messMenuQuerySchema,
        response: { 200: messMenuSchema, ...errors },
      },
    },
    async (request) => service.menu(requireUserId(request.userId), request.query),
  );

  typed.get(
    '/mess/menu/recommend',
    {
      schema: {
        summary: 'What should I eat at this meal? Up to 3 plates from the mess menu, filtered by YOUR diet and allergies (Phase 10)',
        description:
          'Today or tomorrow only (tomorrow is for planning: not loggable). Allergies are a hard filter — only dishes confirmed ' +
          'free pass; severity never relaxes it. Every number is a range from the stored estimates; reasons are codes. ' +
          'An unavailable menu gets no plates; an inferred one is labelled. Nothing is stored.',
        tags: ['mess'],
        security,
        querystring: messRecommendQuerySchema,
        response: { 200: messRecommendationSchema, ...errors },
      },
    },
    async (request) => recommend.recommend(requireUserId(request.userId), request.query),
  );

  typed.post(
    '/mess/dishes/:slug/correction',
    {
      config: { rateLimit: CORRECTION_RATE_LIMIT },
      schema: {
        summary: "Report a dish's estimate as wrong. Stored as pending; changes nothing until reviewed. Retry-safe (201, then 200)",
        tags: ['mess'],
        security,
        params: dishSlugParamsSchema,
        body: messCorrectionRequestSchema,
        response: { 200: messCorrectionSchema, 201: messCorrectionSchema, 429: errorEnvelopeSchema, ...errors },
      },
    },
    async (request, reply) => {
      const { correction, created } = await service.correct(requireUserId(request.userId), request.params.slug, request.body);
      return reply.code(created ? 201 : 200).send(correction);
    },
  );
}
