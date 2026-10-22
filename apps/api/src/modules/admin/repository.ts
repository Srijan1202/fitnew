/**
 * Phase 16 — admin reads and writes (MASTER-SPEC §20, ADR-022). Every write
 * goes through `inTransaction` with its audit row; the service decides.
 */
import { and, asc, count, desc, eq, gte, ilike, inArray, isNotNull, isNull, lt, max, or, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import {
  aiUsage,
  auditLogs,
  bodyMetrics,
  exerciseContraindications,
  exerciseMuscles,
  exercises,
  featureFlags,
  foodAliases,
  foodLogs,
  foodNutrition,
  foods,
  messDishCorrections,
  messDishNutrition,
  messDishNutritionRevisions,
  messDishOverrides,
  messes,
  notifications,
  recommendationEvents,
  recommendations,
  recoveryLogs,
  userGoals,
  userPreferences,
  userProfiles,
  users,
  workoutSessions,
} from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export interface AuditEntry {
  readonly actorUserId: string | null;
  readonly action: string;
  readonly entity: string;
  readonly entityId: string | null;
  readonly metadata?: Record<string, unknown>;
}

const n = (v: string | null): number | null => (v === null ? null : Number(v));

export class AdminRepository {
  constructor(private readonly db: Db) {}

  /** A unit of work with its audit row: both commit, or neither. */
  async inTransaction<T>(fn: (repo: AdminRepository) => Promise<T>): Promise<T> {
    return this.db.transaction(async (tx) => fn(new AdminRepository(tx as unknown as Db)));
  }

  async audit(e: AuditEntry): Promise<void> {
    await this.db.insert(auditLogs).values({ ...e, metadata: e.metadata ?? {} });
  }

  /** users.id for each Firebase uid that has used FITOS. */
  async userIdsByFirebaseUid(uids: readonly string[]): Promise<Map<string, string>> {
    if (uids.length === 0) return new Map();
    const rows = await this.db.select({ uid: users.firebaseUid, id: users.id }).from(users).where(inArray(users.firebaseUid, [...uids]));
    return new Map(rows.map((r) => [r.uid, r.id]));
  }

  /* ---------------------------------------------------------- overview -- */

  async endpoints() {
    return this.db.select().from(messes).orderBy(asc(messes.code));
  }

  async pendingCorrections(): Promise<number> {
    const [r] = await this.db.select({ n: count() }).from(messDishCorrections).where(eq(messDishCorrections.status, 'pending'));
    return Number(r?.n ?? 0);
  }

  async userCounts(since: Date): Promise<{ total: number; active: number }> {
    const [total] = await this.db.select({ n: count() }).from(users).where(isNull(users.deletedAt));
    const [active] = await this.db.execute<{ n: number }>(sql`
      select count(*)::int as n from (
        select user_id from ${workoutSessions} where ${workoutSessions.startedAt} >= ${since.toISOString()}
        union select user_id from ${foodLogs} where ${foodLogs.loggedAt} >= ${since.toISOString()} and ${foodLogs.deletedAt} is null
      ) a`);
    return { total: Number(total?.n ?? 0), active: Number((active as { n: number } | undefined)?.n ?? 0) };
  }

  async recommendationFunnel(since: Date): Promise<{ kind: string; event: string; n: number }[]> {
    const rows = await this.db
      .select({ kind: recommendations.kind, event: recommendationEvents.event, n: sql<number>`count(distinct ${recommendationEvents.recommendationId})::int` })
      .from(recommendationEvents)
      .innerJoin(recommendations, eq(recommendations.id, recommendationEvents.recommendationId))
      .where(gte(recommendationEvents.occurredAt, since))
      .groupBy(recommendations.kind, recommendationEvents.event);
    return rows.map((r) => ({ kind: r.kind, event: r.event, n: Number(r.n) }));
  }

  async notificationFunnel(since: Date, until: Date): Promise<{ kind: string; status: string; n: number }[]> {
    const rows = await this.db
      .select({ kind: notifications.kind, status: notifications.status, n: count() })
      .from(notifications)
      .where(and(gte(notifications.scheduledFor, since), lt(notifications.scheduledFor, until)))
      .groupBy(notifications.kind, notifications.status);
    return rows.map((r) => ({ kind: r.kind, status: r.status, n: Number(r.n) }));
  }

  /* -------------------------------------------------------- corrections -- */

  async corrections(status: 'pending' | 'accepted' | 'rejected') {
    return this.db
      .select()
      .from(messDishCorrections)
      .where(eq(messDishCorrections.status, status))
      .orderBy(asc(messDishCorrections.dishSlug), asc(messDishCorrections.createdAt))
      .limit(500);
  }

  async correction(id: string) {
    const [r] = await this.db.select().from(messDishCorrections).where(eq(messDishCorrections.id, id)).limit(1);
    return r ?? null;
  }

  async reviewCorrection(id: string, status: 'accepted' | 'rejected', reviewer: string | null): Promise<void> {
    await this.db
      .update(messDishCorrections)
      .set({ status, reviewedBy: reviewer, reviewedAt: sql`now()` })
      .where(and(eq(messDishCorrections.id, id), eq(messDishCorrections.status, 'pending')));
  }

  async dishEstimates(slugs: readonly string[]) {
    if (slugs.length === 0) return new Map<string, typeof messDishNutrition.$inferSelect>();
    const rows = await this.db.select().from(messDishNutrition).where(inArray(messDishNutrition.dishSlug, [...new Set(slugs)]));
    return new Map(rows.map((r) => [r.dishSlug, r]));
  }

  async overrides(slugs: readonly string[]): Promise<Map<string, 'veg' | 'egg' | 'nonveg'>> {
    if (slugs.length === 0) return new Map();
    const rows = await this.db.select().from(messDishOverrides).where(inArray(messDishOverrides.dishSlug, [...new Set(slugs)]));
    return new Map(rows.map((r) => [r.dishSlug, r.diet as 'veg' | 'egg' | 'nonveg']));
  }

  /** A stored estimate changed by review, with its provenance (Phase 10 revisions). */
  async reviseEstimate(slug: string, ranges: Record<string, number>, reason: string): Promise<void> {
    const [before] = await this.db.select().from(messDishNutrition).where(eq(messDishNutrition.dishSlug, slug)).limit(1);
    if (before === undefined) return;
    const pick = (r: typeof before) => ({
      kcalLow: n(r.kcalLow), kcalHigh: n(r.kcalHigh), proteinLow: n(r.proteinLow), proteinHigh: n(r.proteinHigh),
      carbLow: n(r.carbLow), carbHigh: n(r.carbHigh), fatLow: n(r.fatLow), fatHigh: n(r.fatHigh),
    });
    const set = Object.fromEntries(Object.entries(ranges).map(([k, v]) => [k, v.toFixed(2)]));
    await this.db.update(messDishNutrition).set({ ...set, updatedAt: sql`now()` }).where(eq(messDishNutrition.dishSlug, slug));
    await this.db.insert(messDishNutritionRevisions).values({ dishSlug: slug, reason, previous: pick(before), current: { ...pick(before), ...ranges } });
  }

  async setDiet(slug: string, diet: 'veg' | 'egg' | 'nonveg' | null, reason: string, actor: string | null): Promise<void> {
    if (diet === null) {
      await this.db.delete(messDishOverrides).where(eq(messDishOverrides.dishSlug, slug));
      return;
    }
    await this.db
      .insert(messDishOverrides)
      .values({ dishSlug: slug, diet, reason, updatedBy: actor })
      .onConflictDoUpdate({ target: messDishOverrides.dishSlug, set: { diet, reason, updatedBy: actor, updatedAt: sql`now()` } });
  }

  /* -------------------------------------------------------------- foods -- */

  async foods(q: string) {
    const where = and(
      isNull(foods.ownerUserId),
      q === '' ? undefined : or(ilike(foods.name, `%${q}%`), ilike(foods.slug, `%${q.replace(/\s+/g, '-')}%`)),
    );
    return this.db.select().from(foods).where(where).orderBy(asc(foods.name)).limit(100);
  }

  async food(id: string) {
    const [f] = await this.db.select().from(foods).where(and(eq(foods.id, id), isNull(foods.ownerUserId))).limit(1);
    if (f === undefined) return null;
    const [rows, aliases] = await Promise.all([
      this.db.select().from(foodNutrition).where(eq(foodNutrition.foodId, id)).orderBy(asc(foodNutrition.position)),
      this.db.select().from(foodAliases).where(eq(foodAliases.foodId, id)),
    ]);
    return { food: f, rows, aliases: aliases.map((a) => a.alias) };
  }

  async replaceFood(
    id: string,
    input: { name: string; isVerified: boolean; aliases: readonly string[]; nutrition: readonly Record<string, unknown>[] },
  ): Promise<void> {
    await this.db
      .update(foods)
      .set({ name: input.name, isVerified: input.isVerified, adminEditedAt: sql`now()`, updatedAt: sql`now()` })
      .where(eq(foods.id, id));
    await this.db.delete(foodNutrition).where(eq(foodNutrition.foodId, id));
    await this.db.delete(foodAliases).where(eq(foodAliases.foodId, id));
    const num = (v: unknown): string | null => (v === null || v === undefined ? null : String(v));
    await this.db.insert(foodNutrition).values(
      input.nutrition.map((r, position) => ({
        foodId: id,
        position,
        basis: r['basis'] as 'per_100g' | 'per_serving',
        servingLabel: r['servingLabel'] as string,
        servingGrams: num(r['servingGrams']),
        kcalLow: num(r['kcalLow'])!,
        kcalHigh: num(r['kcalHigh'])!,
        proteinLow: num(r['proteinLow'])!,
        proteinHigh: num(r['proteinHigh'])!,
        carbLow: num(r['carbLow'])!,
        carbHigh: num(r['carbHigh'])!,
        fatLow: num(r['fatLow'])!,
        fatHigh: num(r['fatHigh'])!,
        fibreLow: num(r['fibreLow']),
        fibreHigh: num(r['fibreHigh']),
        confidence: r['confidence'] as 'high' | 'medium' | 'low',
      })),
    );
    if (input.aliases.length > 0) {
      await this.db.insert(foodAliases).values([...new Set(input.aliases)].map((alias) => ({ foodId: id, alias })));
    }
  }

  /* ---------------------------------------------------------- exercises -- */

  async exercises(q: string, retired: boolean) {
    return this.db
      .select()
      .from(exercises)
      .where(and(retired ? isNotNull(exercises.retiredAt) : isNull(exercises.retiredAt), q === '' ? undefined : or(ilike(exercises.name, `%${q}%`), ilike(exercises.slug, `%${q}%`))))
      .orderBy(asc(exercises.name))
      .limit(300);
  }

  async exercise(id: string) {
    const [x] = await this.db.select().from(exercises).where(eq(exercises.id, id)).limit(1);
    if (x === undefined) return null;
    const [muscles, contra] = await Promise.all([
      this.db.select().from(exerciseMuscles).where(eq(exerciseMuscles.exerciseId, id)).orderBy(asc(exerciseMuscles.role), asc(exerciseMuscles.position)),
      this.db.select().from(exerciseContraindications).where(eq(exerciseContraindications.exerciseId, id)),
    ]);
    return { exercise: x, muscles, contraindications: contra.map((c) => c.bodyPart) };
  }

  async exerciseIdBySlug(slug: string): Promise<string | null> {
    const [x] = await this.db.select({ id: exercises.id }).from(exercises).where(eq(exercises.slug, slug)).limit(1);
    return x?.id ?? null;
  }

  async writeExercise(
    id: string | null,
    input: {
      slug?: string;
      name: string;
      movementPattern: (typeof exercises.$inferInsert)['movementPattern'];
      equipment: (typeof exercises.$inferInsert)['equipment'];
      difficulty: (typeof exercises.$inferInsert)['difficulty'];
      isUnilateral: boolean;
      defaultIncrementKg: number;
      instructions: string[];
      videoUrl: string | null;
      primaryMuscles: (typeof exerciseMuscles.$inferInsert)['muscleGroup'][];
      secondaryMuscles: (typeof exerciseMuscles.$inferInsert)['muscleGroup'][];
      contraindications: (typeof exerciseContraindications.$inferInsert)['bodyPart'][];
    },
  ): Promise<string> {
    const cols = {
      name: input.name,
      movementPattern: input.movementPattern,
      equipment: input.equipment,
      difficulty: input.difficulty,
      isUnilateral: input.isUnilateral,
      defaultIncrementKg: input.defaultIncrementKg.toFixed(2),
      instructions: input.instructions,
      videoUrl: input.videoUrl,
      adminEditedAt: sql`now()`,
      updatedAt: sql`now()`,
    };
    let exerciseId: string;
    if (id === null) {
      const [row] = await this.db.insert(exercises).values({ slug: input.slug!, ...cols }).returning({ id: exercises.id });
      exerciseId = row!.id;
    } else {
      await this.db.update(exercises).set(cols).where(eq(exercises.id, id));
      exerciseId = id;
      await this.db.delete(exerciseMuscles).where(eq(exerciseMuscles.exerciseId, id));
      await this.db.delete(exerciseContraindications).where(eq(exerciseContraindications.exerciseId, id));
    }
    await this.db.insert(exerciseMuscles).values([
      ...input.primaryMuscles.map((m, position) => ({ exerciseId, muscleGroup: m, role: 'primary' as const, contribution: '1.00', position })),
      ...input.secondaryMuscles.map((m, position) => ({ exerciseId, muscleGroup: m, role: 'secondary' as const, contribution: '0.50', position })),
    ]);
    if (input.contraindications.length > 0) {
      await this.db.insert(exerciseContraindications).values([...new Set(input.contraindications)].map((bodyPart) => ({ exerciseId, bodyPart })));
    }
    return exerciseId;
  }

  async setRetired(id: string, retired: boolean): Promise<void> {
    await this.db
      .update(exercises)
      .set({ retiredAt: retired ? sql`now()` : null, adminEditedAt: sql`now()`, updatedAt: sql`now()` })
      .where(eq(exercises.id, id));
  }

  /* -------------------------------------------------------------- flags -- */

  async flags() {
    return this.db.select().from(featureFlags).orderBy(asc(featureFlags.key));
  }

  async putFlag(key: string, enabled: boolean, description: string | undefined, actor: string | null) {
    const [row] = await this.db
      .insert(featureFlags)
      .values({ key, enabled, description: description ?? '', updatedBy: actor })
      .onConflictDoUpdate({
        target: featureFlags.key,
        set: { enabled, ...(description !== undefined ? { description } : {}), updatedBy: actor, updatedAt: sql`now()` },
      })
      .returning();
    return row!;
  }

  /* ------------------------------------------------------------ support -- */

  async userByEmail(email: string) {
    const [u] = await this.db.select().from(users).where(and(sql`lower(${users.email}) = lower(${email})`, isNull(users.deletedAt))).limit(1);
    return u ?? null;
  }

  async userById(id: string) {
    const [u] = await this.db.select().from(users).where(and(eq(users.id, id), isNull(users.deletedAt))).limit(1);
    return u ?? null;
  }

  async supportFacts(userId: string, since7d: Date) {
    const [profile, goal, prefs, sessions, logs, weighIns, checkIns, ai] = await Promise.all([
      this.db.select({ stage: userProfiles.onboardingStage }).from(userProfiles).where(eq(userProfiles.userId, userId)).limit(1),
      this.db.select({ goalType: userGoals.goalType }).from(userGoals).where(and(eq(userGoals.userId, userId), isNull(userGoals.endedAt))).limit(1),
      this.db.select({ s: userPreferences.notificationSettings }).from(userPreferences).where(eq(userPreferences.userId, userId)).limit(1),
      this.db.select({ n: count(), last: max(workoutSessions.startedAt) }).from(workoutSessions).where(eq(workoutSessions.userId, userId)),
      this.db.select({ n: count(), last: max(foodLogs.loggedAt) }).from(foodLogs).where(and(eq(foodLogs.userId, userId), isNull(foodLogs.deletedAt))),
      this.db.select({ n: count(), last: max(bodyMetrics.measuredOn) }).from(bodyMetrics).where(and(eq(bodyMetrics.userId, userId), isNull(bodyMetrics.deletedAt))),
      this.db.select({ n: count(), last: max(recoveryLogs.loggedOn) }).from(recoveryLogs).where(eq(recoveryLogs.userId, userId)),
      this.db.select({ n: count() }).from(aiUsage).where(and(eq(aiUsage.userId, userId), gte(aiUsage.createdAt, since7d))),
    ]);
    return {
      stage: profile[0]?.stage ?? null,
      goal: goal[0]?.goalType ?? null,
      notificationSettings: prefs[0]?.s ?? {},
      sessions: { n: Number(sessions[0]?.n ?? 0), last: sessions[0]?.last ?? null },
      foodLogs: { n: Number(logs[0]?.n ?? 0), last: logs[0]?.last ?? null },
      weighIns: { n: Number(weighIns[0]?.n ?? 0), last: weighIns[0]?.last ?? null },
      checkIns: { n: Number(checkIns[0]?.n ?? 0), last: checkIns[0]?.last ?? null },
      aiCalls7d: Number(ai[0]?.n ?? 0),
    };
  }

  /* -------------------------------------------------------------- audit -- */

  async auditPage(limit: number, before: Date | null) {
    return this.db
      .select({
        id: auditLogs.id,
        actorUserId: auditLogs.actorUserId,
        actorEmail: users.email,
        action: auditLogs.action,
        entity: auditLogs.entity,
        entityId: auditLogs.entityId,
        metadata: auditLogs.metadata,
        occurredAt: auditLogs.occurredAt,
      })
      .from(auditLogs)
      .leftJoin(users, eq(users.id, auditLogs.actorUserId))
      .where(before === null ? undefined : lt(auditLogs.occurredAt, before))
      .orderBy(desc(auditLogs.occurredAt), desc(auditLogs.id))
      .limit(limit);
  }
}
