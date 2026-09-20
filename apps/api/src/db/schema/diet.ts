/**
 * Diet, allergies, limitations (§9.2).
 */
import { sql } from 'drizzle-orm';
import { boolean, index, jsonb, pgTable, text, timestamp, uniqueIndex, uuid } from 'drizzle-orm/pg-core';

import { allergenEnum, allergySeverityEnum, bodyPartEnum, budgetTierEnum, dietTypeEnum } from './enums.js';
import { users } from './users.js';

const userRef = () =>
  uuid('user_id')
    .notNull()
    .references(() => users.id, { onDelete: 'cascade' });

export const dietPreferences = pgTable('diet_preferences', {
  userId: userRef().primaryKey(),
  dietType: dietTypeEnum('diet_type').notNull(),
  /** Dish slugs the user has rejected (§15.1 hard exclusion). */
  excludedDishIds: jsonb('excluded_dish_ids').notNull().default(sql`'[]'::jsonb`),
  budgetTier: budgetTierEnum('budget_tier'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

/**
 * SAFETY-CRITICAL (§9.2, §14.5). Every food recommendation applies these as
 * a hard filter before scoring — never as a penalty term. One row per
 * (user, allergen) so a severity update is an upsert, not a duplicate.
 */
export const userAllergies = pgTable(
  'user_allergies',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: userRef(),
    allergen: allergenEnum('allergen').notNull(),
    severity: allergySeverityEnum('severity').notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [uniqueIndex('user_allergies_user_allergen').on(t.userId, t.allergen)],
);

/** Drives exercise substitution (§12.6). Collected later per §32; table now. */
export const userLimitations = pgTable(
  'user_limitations',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    userId: userRef(),
    bodyPart: bodyPartEnum('body_part').notNull(),
    note: text('note'),
    active: boolean('active').notNull().default(true),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index('user_limitations_user_active_idx').on(t.userId, t.active)],
);

export type DietPreferencesRow = typeof dietPreferences.$inferSelect;
export type UserAllergyRow = typeof userAllergies.$inferSelect;
