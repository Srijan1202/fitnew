/**
 * Persistence for profile, goals, diet, preferences, consent, targets and
 * body readings. Drizzle only — no fitness rules, no identity logic (§8.3).
 * Every query is scoped by a `userId` the caller obtained from a verified
 * token; nothing here ever takes one from a request body.
 */
import { and, desc, eq, isNull, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import {
  bodyMetrics,
  consentRecords,
  dietPreferences,
  nutritionTargets,
  userAllergies,
  userGoals,
  userPreferences,
  userProfiles,
  users,
  type BodyMetricRow,
  type DietPreferencesRow,
  type NutritionTargetsRow,
  type UserAllergyRow,
  type UserGoalRow,
  type UserPreferencesRow,
  type UserProfileRow,
} from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export interface ProfileBundle {
  readonly user: { readonly displayName: string | null; readonly timezone: string; readonly locale: string };
  readonly profile: UserProfileRow | null;
  readonly goal: UserGoalRow | null;
  readonly diet: DietPreferencesRow | null;
  readonly allergies: readonly UserAllergyRow[];
  readonly preferences: UserPreferencesRow | null;
  readonly latestWeight: BodyMetricRow | null;
  readonly targets: NutritionTargetsRow | null;
}

export class UserRepository {
  constructor(private readonly db: Db) {}

  /** Everything the profile and onboarding endpoints need, in one round trip per table. */
  async loadBundle(userId: string): Promise<ProfileBundle | null> {
    const [user] = await this.db
      .select({ displayName: users.displayName, timezone: users.timezone, locale: users.locale })
      .from(users)
      .where(eq(users.id, userId));
    if (user === undefined) return null;

    const [profile, goal, diet, allergies, preferences, latestWeight, targets] = await Promise.all([
      this.db.select().from(userProfiles).where(eq(userProfiles.userId, userId)).then((r) => r[0] ?? null),
      this.activeGoal(userId),
      this.db.select().from(dietPreferences).where(eq(dietPreferences.userId, userId)).then((r) => r[0] ?? null),
      this.db.select().from(userAllergies).where(eq(userAllergies.userId, userId)).orderBy(userAllergies.allergen),
      this.db.select().from(userPreferences).where(eq(userPreferences.userId, userId)).then((r) => r[0] ?? null),
      this.latestWeight(userId),
      this.currentTargets(userId),
    ]);

    return { user, profile, goal, diet, allergies, preferences, latestWeight, targets };
  }

  /* ------------------------------------------------------------ profile -- */

  async upsertProfile(
    userId: string,
    patch: Partial<Omit<UserProfileRow, 'userId' | 'createdAt' | 'updatedAt'>>,
  ): Promise<UserProfileRow> {
    const [row] = await this.db
      .insert(userProfiles)
      .values({ userId, ...patch })
      .onConflictDoUpdate({
        target: userProfiles.userId,
        set: { ...patch, updatedAt: sql`now()` },
      })
      .returning();
    if (row === undefined) throw new Error('profile upsert returned no row');
    return row;
  }

  /** Phase 6.6: the canonical display name lives on `users`. */
  async updateDisplayName(userId: string, displayName: string): Promise<void> {
    await this.db
      .update(users)
      .set({ displayName, updatedAt: sql`now()` })
      .where(eq(users.id, userId));
  }

  async updateUserLocale(userId: string, patch: { timezone?: string; locale?: string }): Promise<void> {
    if (patch.timezone === undefined && patch.locale === undefined) return;
    await this.db
      .update(users)
      .set({ ...patch, updatedAt: sql`now()` })
      .where(eq(users.id, userId));
  }

  /* --------------------------------------------------------------- goal -- */

  async activeGoal(userId: string): Promise<UserGoalRow | null> {
    const [row] = await this.db
      .select()
      .from(userGoals)
      .where(and(eq(userGoals.userId, userId), isNull(userGoals.endedAt)))
      .limit(1);
    return row ?? null;
  }

  /**
   * Close the active goal (if any) and open a new one, atomically. The
   * partial unique index guarantees there is never more than one open row,
   * so this is safe even under concurrent PUTs — the loser gets a unique
   * violation rather than two active goals.
   */
  async replaceGoal(
    userId: string,
    goal: { goalType: UserGoalRow['goalType']; targetWeightKg: string | null },
  ): Promise<UserGoalRow> {
    return this.db.transaction(async (tx) => {
      await tx
        .update(userGoals)
        .set({ endedAt: sql`now()` })
        .where(and(eq(userGoals.userId, userId), isNull(userGoals.endedAt)));
      const [row] = await tx
        .insert(userGoals)
        .values({ userId, goalType: goal.goalType, targetWeightKg: goal.targetWeightKg })
        .returning();
      if (row === undefined) throw new Error('goal insert returned no row');
      return row;
    });
  }

  /* ---------------------------------------------------------------- diet -- */

  async replaceDiet(
    userId: string,
    diet: { dietType: DietPreferencesRow['dietType']; excludedDishIds?: string[]; budgetTier?: DietPreferencesRow['budgetTier'] },
    allergies: readonly { allergen: UserAllergyRow['allergen']; severity: UserAllergyRow['severity'] }[],
  ): Promise<void> {
    await this.db.transaction(async (tx) => {
      await tx
        .insert(dietPreferences)
        .values({
          userId,
          dietType: diet.dietType,
          ...(diet.excludedDishIds !== undefined ? { excludedDishIds: diet.excludedDishIds } : {}),
          ...(diet.budgetTier !== undefined ? { budgetTier: diet.budgetTier } : {}),
        })
        .onConflictDoUpdate({
          target: dietPreferences.userId,
          set: {
            dietType: diet.dietType,
            ...(diet.excludedDishIds !== undefined ? { excludedDishIds: diet.excludedDishIds } : {}),
            ...(diet.budgetTier !== undefined ? { budgetTier: diet.budgetTier } : {}),
            updatedAt: sql`now()`,
          },
        });
      // Allergies are replaced wholesale: the list the client sends IS the
      // list. A removed allergen must actually go away — it is a hard filter.
      await tx.delete(userAllergies).where(eq(userAllergies.userId, userId));
      if (allergies.length > 0) {
        await tx.insert(userAllergies).values(allergies.map((a) => ({ userId, ...a })));
      }
    });
  }

  /* --------------------------------------------------------- preferences -- */

  async upsertPreferences(
    userId: string,
    patch: { units?: UserPreferencesRow['units']; notificationSettings?: Record<string, unknown> },
  ): Promise<UserPreferencesRow> {
    const [row] = await this.db
      .insert(userPreferences)
      .values({ userId, ...patch })
      .onConflictDoUpdate({ target: userPreferences.userId, set: { ...patch, updatedAt: sql`now()` } })
      .returning();
    if (row === undefined) throw new Error('preferences upsert returned no row');
    return row;
  }

  /* ------------------------------------------------------------- consent -- */

  /** Append-only by construction: there is no update method on this table. */
  async recordConsent(
    rows: readonly {
      userId: string;
      consentType: (typeof consentRecords.$inferInsert)['consentType'];
      granted: boolean;
      policyVersion: string;
      ipHash: string | null;
    }[],
  ): Promise<void> {
    if (rows.length > 0) await this.db.insert(consentRecords).values([...rows]);
  }

  /* ---------------------------------------------------------------- body -- */

  async latestWeight(userId: string): Promise<BodyMetricRow | null> {
    const [row] = await this.db
      .select()
      .from(bodyMetrics)
      .where(and(eq(bodyMetrics.userId, userId), isNull(bodyMetrics.deletedAt)))
      .orderBy(desc(bodyMetrics.measuredOn))
      .limit(1);
    return row ?? null;
  }

  /** One reading per day: a second weigh-in on the same date replaces the first. */
  async upsertWeight(
    userId: string,
    reading: { measuredOn: string; weightKg: string; source: BodyMetricRow['source'] },
  ): Promise<BodyMetricRow> {
    const [row] = await this.db
      .insert(bodyMetrics)
      .values({ userId, ...reading })
      .onConflictDoUpdate({
        target: [bodyMetrics.userId, bodyMetrics.measuredOn],
        set: { weightKg: reading.weightKg, source: reading.source, deletedAt: null },
      })
      .returning();
    if (row === undefined) throw new Error('weight upsert returned no row');
    return row;
  }

  /* ------------------------------------------------------------- targets -- */

  async currentTargets(userId: string): Promise<NutritionTargetsRow | null> {
    const [row] = await this.db
      .select()
      .from(nutritionTargets)
      .where(eq(nutritionTargets.userId, userId))
      .orderBy(desc(nutritionTargets.effectiveFrom), desc(nutritionTargets.createdAt))
      .limit(1);
    return row ?? null;
  }

  /** History only: a new row every time. Past rows are never mutated (§9.2). */
  async insertTargets(row: typeof nutritionTargets.$inferInsert): Promise<NutritionTargetsRow> {
    const [inserted] = await this.db.insert(nutritionTargets).values(row).returning();
    if (inserted === undefined) throw new Error('targets insert returned no row');
    return inserted;
  }
}
