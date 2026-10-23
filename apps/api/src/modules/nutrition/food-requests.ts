/**
 * Beta 3.2 (ADR-032): foods people searched for and did not find.
 *
 * `POST /nutrition/foods/requests` — the app reports a search that found
 * nothing (and "Ask us to add it"). The server re-runs the search: text that
 * does find a food is not counted. Each person counts once a day and once
 * overall, through salted hashes; no user id is stored.
 *
 * `GET /admin/foods/requests` and `PATCH /admin/foods/requests/:id` — the
 * admin panel's list, most-wanted first, and its status (audited).
 */
import { createHash } from 'node:crypto';

import { and, desc, eq, inArray, ne, sql } from 'drizzle-orm';
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import {
  adminCommunityFoodListSchema,
  adminCommunityFoodQuerySchema,
  adminCommunityFoodSchema,
  adminFoodRequestListSchema,
  adminFoodRequestQuerySchema,
  adminFoodRequestSchema,
  errorEnvelopeSchema,
  reportFoodRequestSchema,
  reportMissingFoodRequestSchema,
  setCommunityFoodVisibilityRequestSchema,
  setFoodRequestStatusRequestSchema,
  type AdminCommunityFood,
  type AdminFoodRequest,
  type FoodRequestStatus,
} from '@fitos/contracts';
import { normaliseFoodText } from '@fitos/core/nutrition/food';

import type { DatabaseHandle } from '../../db/client.js';
import { auditLogs, foodNutrition, foodReports, foodRequestMarks, foodRequests, foods, type FoodRequestRow } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import { requireAdmin } from '../../plugins/auth.js';
import { FoodRepository } from './repository.js';

type Db = DatabaseHandle['db'];

/** Reports a person may send in an hour: plenty for typing, too few for a flood. */
export const FOOD_REQUESTS_PER_HOUR = 30;
/** The stored text's length (the column's check allows 2–60). */
export const FOOD_REQUEST_MAX = 60;

function out(r: FoodRequestRow): AdminFoodRequest {
  return {
    id: r.id,
    query: r.query,
    searches: r.searches,
    people: r.people,
    asked: r.asked,
    status: r.status as FoodRequestStatus,
    firstSeenAt: r.firstSeenAt.toISOString(),
    lastSeenAt: r.lastSeenAt.toISOString(),
    resolvedAt: r.resolvedAt?.toISOString() ?? null,
  };
}

export class FoodRequestService {
  constructor(
    private readonly db: Db,
    private readonly foods: FoodRepository,
    private readonly salt: string,
  ) {}

  private mark(kind: string, userId: string, query: string, extra = ''): string {
    return createHash('sha256').update(`${this.salt}|${kind}|${userId}|${query}|${extra}`).digest('hex');
  }

  /** True when counted; false when the text does find a food (nothing recorded). */
  async report(userId: string, raw: string, asked: boolean, now: Date = new Date()): Promise<boolean> {
    const query = normaliseFoodText(raw).slice(0, FOOD_REQUEST_MAX).trim();
    if (query.length < 2) {
      throw new AppError('VALIDATION_FAILED', 'Type at least two letters.', [{ path: 'query', issue: 'too-short' }]);
    }
    if ((await this.foods.search(query, userId, 1)).length > 0) return false;
    const day = now.toISOString().slice(0, 10);
    await this.db.transaction(async (tx) => {
      const [row] = await tx
        .insert(foodRequests)
        .values({ query })
        .onConflictDoUpdate({ target: foodRequests.query, set: { lastSeenAt: now } })
        .returning({ id: foodRequests.id });
      const id = row!.id;
      const fresh = async (mark: string): Promise<boolean> =>
        (await tx.insert(foodRequestMarks).values({ mark, requestId: id }).onConflictDoNothing().returning({ mark: foodRequestMarks.mark })).length > 0;
      const searches = (await fresh(this.mark('day', userId, query, day))) ? 1 : 0;
      const people = (await fresh(this.mark('person', userId, query))) ? 1 : 0;
      const askedOnce = asked && (await fresh(this.mark('asked', userId, query))) ? 1 : 0;
      if (searches + people + askedOnce > 0) {
        await tx
          .update(foodRequests)
          .set({
            searches: sql`${foodRequests.searches} + ${searches}`,
            people: sql`${foodRequests.people} + ${people}`,
            asked: sql`${foodRequests.asked} + ${askedOnce}`,
          })
          .where(eq(foodRequests.id, id));
      }
    });
    return true;
  }

  async list(status: FoodRequestStatus | 'all', limit: number): Promise<AdminFoodRequest[]> {
    const rows = await this.db
      .select()
      .from(foodRequests)
      .where(status === 'all' ? undefined : eq(foodRequests.status, status))
      .orderBy(desc(foodRequests.people), desc(foodRequests.asked), desc(foodRequests.searches), desc(foodRequests.lastSeenAt))
      .limit(limit);
    return rows.map(out);
  }

  async setStatus(actor: string | null, id: string, status: FoodRequestStatus): Promise<AdminFoodRequest> {
    const row = await this.db.transaction(async (tx) => {
      const [r] = await tx
        .update(foodRequests)
        .set({ status, resolvedAt: status === 'open' ? null : new Date(), resolvedBy: status === 'open' ? null : actor })
        .where(eq(foodRequests.id, id))
        .returning();
      if (r === undefined) return null;
      await tx.insert(auditLogs).values({
        actorUserId: actor,
        action: 'food-request.status',
        entity: 'food_request',
        entityId: id,
        metadata: { status, query: r.query },
      });
      return r;
    });
    if (row === null) throw new AppError('NOT_FOUND', 'No such food request.');
    return out(row);
  }
}

/**
 * Beta 3.2 (ADR-032): community foods — "wrong numbers" reports from anyone
 * who can see one, and the admin panel's list (never who added it), where a
 * shared food can be hidden (back to its owner only) or shown again.
 */
export class CommunityFoodService {
  constructor(
    private readonly db: Db,
    private readonly salt: string,
  ) {}

  /** One report per person per food; reporting your own food or a private one is 404. */
  async report(userId: string, foodId: string, note: string | undefined): Promise<void> {
    const [food] = await this.db
      .select({ id: foods.id })
      .from(foods)
      .where(and(eq(foods.id, foodId), eq(foods.visibility, 'community'), ne(foods.ownerUserId, userId)))
      .limit(1);
    if (food === undefined) throw new AppError('NOT_FOUND', 'No such shared food.');
    const mark = createHash('sha256').update(`${this.salt}|food-report|${userId}|${foodId}`).digest('hex');
    await this.db.insert(foodReports).values({ foodId, mark, note: note ?? null }).onConflictDoNothing();
  }

  async list(filter: 'reported' | 'community' | 'hidden' | 'all', limit: number): Promise<AdminCommunityFood[]> {
    const counts = this.db
      .select({ foodId: foodReports.foodId, n: sql<number>`count(*)::int`.as('n') })
      .from(foodReports)
      .groupBy(foodReports.foodId)
      .as('counts');
    const where =
      filter === 'reported'
        ? and(ne(foods.visibility, 'private'), sql`coalesce(${counts.n}, 0) > 0`)
        : filter === 'all'
          ? ne(foods.visibility, 'private')
          : eq(foods.visibility, filter);
    const rows = await this.db
      .select({ food: foods, reports: sql<number>`coalesce(${counts.n}, 0)` })
      .from(foods)
      .leftJoin(counts, eq(counts.foodId, foods.id))
      .where(where)
      .orderBy(desc(sql`coalesce(${counts.n}, 0)`), desc(foods.createdAt))
      .limit(limit);
    if (rows.length === 0) return [];
    const ids = rows.map((r) => r.food.id);
    const [nutrition, notes] = await Promise.all([
      this.db.select().from(foodNutrition).where(and(inArray(foodNutrition.foodId, ids), eq(foodNutrition.position, 0))),
      this.db
        .select({ foodId: foodReports.foodId, note: foodReports.note })
        .from(foodReports)
        .where(and(inArray(foodReports.foodId, ids), sql`${foodReports.note} is not null`))
        .orderBy(desc(foodReports.createdAt)),
    ]);
    return rows.map(({ food, reports }) => {
      const n = nutrition.find((x) => x.foodId === food.id);
      return {
        id: food.id,
        name: food.name,
        brand: food.brand,
        visibility: food.visibility === 'hidden' ? 'hidden' : 'community',
        basis: n?.basis ?? 'per_100g',
        servingLabel: n?.servingLabel ?? null,
        kcal: Number(n?.kcalHigh ?? 0),
        proteinG: Number(n?.proteinHigh ?? 0),
        carbG: Number(n?.carbHigh ?? 0),
        fatG: Number(n?.fatHigh ?? 0),
        reports: Number(reports),
        notes: notes.filter((x) => x.foodId === food.id).slice(0, 3).map((x) => x.note as string),
        createdAt: food.createdAt.toISOString(),
      };
    });
  }

  async setVisibility(actor: string | null, id: string, visibility: 'community' | 'hidden'): Promise<AdminCommunityFood> {
    const updated = await this.db.transaction(async (tx) => {
      const [r] = await tx
        .update(foods)
        .set({ visibility, updatedAt: new Date() })
        .where(and(eq(foods.id, id), ne(foods.visibility, 'private')))
        .returning({ id: foods.id, name: foods.name });
      if (r === undefined) return null;
      await tx.insert(auditLogs).values({
        actorUserId: actor,
        action: 'community-food.visibility',
        entity: 'food',
        entityId: id,
        metadata: { visibility, name: r.name },
      });
      return r;
    });
    if (updated === null) throw new AppError('NOT_FOUND', 'No such shared food.');
    const all = await this.list('all', 200);
    const found = all.find((x) => x.id === id);
    if (found === undefined) throw new AppError('NOT_FOUND', 'No such shared food.');
    return found;
  }
}

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

export async function foodRequestRoutes(app: FastifyInstance, opts: { salt: string }): Promise<void> {
  const service = new FoodRequestService(app.database.db, new FoodRepository(app.database.db), opts.salt);
  const community = new CommunityFoodService(app.database.db, opts.salt);
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 403: errorEnvelopeSchema, 404: errorEnvelopeSchema, 422: errorEnvelopeSchema, 429: errorEnvelopeSchema };

  typed.post('/nutrition/foods/requests', {
    config: {
      rateLimit: {
        max: FOOD_REQUESTS_PER_HOUR,
        timeWindow: '1 hour',
        hook: 'preHandler',
        keyGenerator: (request: FastifyRequest): string =>
          request.userId !== null ? `food-request:${request.userId}` : `food-request-ip:${request.ip}`,
      },
    },
    schema: {
      summary: 'Report a food search that found nothing (or "Ask us to add it"); counted anonymously, once per person a day',
      tags: ['nutrition'],
      security,
      body: reportMissingFoodRequestSchema,
      response: { 204: z.null(), ...errors },
    },
  }, async (request, reply) => {
    const userId = requireUserId(request.userId);
    await app.features.require('food-requests');
    await service.report(userId, request.body.query, request.body.asked);
    return reply.code(204).send(null);
  });

  const admin = { preValidation: requireAdmin };

  typed.get('/admin/foods/requests', {
    ...admin,
    schema: {
      summary: 'Foods people searched for and did not find, most-wanted first',
      tags: ['admin'],
      security,
      querystring: adminFoodRequestQuerySchema,
      response: { 200: adminFoodRequestListSchema, ...errors },
    },
  }, async (request) => ({ items: await service.list(request.query.status, request.query.limit) }));

  typed.patch('/admin/foods/requests/:id', {
    ...admin,
    schema: {
      summary: 'Mark a food request added, already there, ignored or open again (audited)',
      tags: ['admin'],
      security,
      params: z.object({ id: z.string().uuid() }).strict(),
      body: setFoodRequestStatusRequestSchema,
      response: { 200: adminFoodRequestSchema, ...errors },
    },
  }, async (request) => service.setStatus(request.userId, request.params.id, request.body.status));

  typed.post('/nutrition/foods/:id/report', {
    config: {
      rateLimit: {
        max: FOOD_REQUESTS_PER_HOUR,
        timeWindow: '1 hour',
        hook: 'preHandler',
        keyGenerator: (request: FastifyRequest): string =>
          request.userId !== null ? `food-report:${request.userId}` : `food-report-ip:${request.ip}`,
      },
    },
    schema: {
      summary: "Report wrong numbers on someone else's shared food (once per person; anonymous)",
      tags: ['nutrition'],
      security,
      params: z.object({ id: z.string().uuid() }).strict(),
      body: reportFoodRequestSchema,
      response: { 204: z.null(), ...errors },
    },
  }, async (request, reply) => {
    const userId = requireUserId(request.userId);
    await app.features.require('community-foods');
    await community.report(userId, request.params.id, request.body.note);
    return reply.code(204).send(null);
  });

  typed.get('/admin/foods/community', {
    ...admin,
    schema: {
      summary: 'Shared foods, most-reported first (never who added them)',
      tags: ['admin'],
      security,
      querystring: adminCommunityFoodQuerySchema,
      response: { 200: adminCommunityFoodListSchema, ...errors },
    },
  }, async (request) => ({ items: await community.list(request.query.filter, request.query.limit) }));

  typed.patch('/admin/foods/community/:id', {
    ...admin,
    schema: {
      summary: 'Hide a shared food (back to its owner only) or show it again (audited)',
      tags: ['admin'],
      security,
      params: z.object({ id: z.string().uuid() }).strict(),
      body: setCommunityFoodVisibilityRequestSchema,
      response: { 200: adminCommunityFoodSchema, ...errors },
    },
  }, async (request) => community.setVisibility(request.userId, request.params.id, request.body.visibility));
}
