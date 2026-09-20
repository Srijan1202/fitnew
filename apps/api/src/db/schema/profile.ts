/**
 * Profile, goals and preferences (§9.2 "Identity & profile").
 */
import { sql } from 'drizzle-orm';
import {
  boolean,
  index,
  jsonb,
  numeric,
  pgTable,
  smallint,
  text,
  timestamp,
  uniqueIndex,
  uuid,
} from 'drizzle-orm/pg-core';

import {
  activityLevelEnum,
  equipmentEnum,
  experienceLevelEnum,
  goalTypeEnum,
  onboardingStageEnum,
  sexEnum,
  trainingLocationEnum,
  unitsEnum,
} from './enums.js';
import { users } from './users.js';

const userRef = () =>
  uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' });

const timestamps = {
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
};

/**
 * 1:1 with users. Everything nullable until onboarding fills it; the
 * `onboarding_stage` column names the next step so a killed app resumes
 * exactly where it was (§32).
 *
 * Weight is NOT here — it is a reading, and lives in body_metrics as a series
 * the trend engine consumes (§9.2, §13.2).
 *
 * The training-location, equipment and mess columns are Phase 2 additions
 * §9.2 does not list: §32 collects them on screens 4 and 6 and there was no
 * other home for them. The mess reference is three text ids matching
 * packages/core's `MessRef`; Phase 9 may add a foreign key once `messes`
 * exists.
 */
export const userProfiles = pgTable('user_profiles', {
  userId: userRef().primaryKey(),
  sex: sexEnum('sex'),
  birthDate: text('birth_date'), // yyyy-mm-dd; a calendar date, never a timestamp
  heightCm: numeric('height_cm', { precision: 4, scale: 1 }),
  experienceLevel: experienceLevelEnum('experience_level'),
  trainingDaysPerWeek: smallint('training_days_per_week'),
  activityLevel: activityLevelEnum('activity_level'),
  preferredSessionMinutes: smallint('preferred_session_minutes'),
  trainingLocation: trainingLocationEnum('training_location'),
  equipment: equipmentEnum('equipment').array().notNull().default(sql`'{}'::equipment[]`),
  isVitStudent: boolean('is_vit_student'),
  messProviderId: text('mess_provider_id'),
  messHostelId: text('mess_hostel_id'),
  messMessId: text('mess_mess_id'),
  onboardingStage: onboardingStageEnum('onboarding_stage').notNull().default('goal'),
  ...timestamps,
});

/**
 * Goal history. The active goal is the row with `ended_at IS NULL`; the
 * partial unique index makes "one active goal" a database fact, not an
 * application hope (§9.3).
 */
export const userGoals = pgTable(
  'user_goals',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: userRef(),
    goalType: goalTypeEnum('goal_type').notNull(),
    targetWeightKg: numeric('target_weight_kg', { precision: 5, scale: 2 }),
    startedAt: timestamp('started_at', { withTimezone: true }).notNull().defaultNow(),
    endedAt: timestamp('ended_at', { withTimezone: true }),
  },
  (t) => [
    uniqueIndex('one_active_goal').on(t.userId).where(sql`${t.endedAt} IS NULL`),
    index('user_goals_user_started_idx').on(t.userId, t.startedAt),
  ],
);

export const userPreferences = pgTable('user_preferences', {
  userId: userRef().primaryKey(),
  units: unitsEnum('units').notNull().default('metric'),
  notificationSettings: jsonb('notification_settings').notNull().default(sql`'{}'::jsonb`),
  featureFlags: jsonb('feature_flags').notNull().default(sql`'{}'::jsonb`),
  ...timestamps,
});

export type UserProfileRow = typeof userProfiles.$inferSelect;
export type UserGoalRow = typeof userGoals.$inferSelect;
export type UserPreferencesRow = typeof userPreferences.$inferSelect;
