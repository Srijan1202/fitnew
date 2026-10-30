/**
 * `users` — the identity root (§9.2).
 *
 * Firebase owns credentials; this table owns everything else. There is no
 * password column and there never will be (§11). `firebase_uid` is the join
 * key to Firebase and is UNIQUE so a token can resolve to at most one row.
 *
 * `timezone` drives every day boundary for this user — "today" is computed
 * here, never in the server's zone (§9.1). It is NOT NULL with a default
 * because a null zone would make "today" undefined for that user.
 *
 * Soft delete (`deleted_at`) is present because §9.2 lists it, but §23's
 * erasure right means a DPDP delete must remove the row and everything
 * cascading from it, not merely set this. Soft delete is for the
 * "deactivated, can be restored" case only.
 */
import { sql } from 'drizzle-orm';
import { boolean, check, index, pgTable, text, timestamp, uuid, type AnyPgColumn } from 'drizzle-orm/pg-core';

export const users = pgTable(
  'users',
  {
    id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
    firebaseUid: text('firebase_uid').notNull().unique(),
    email: text('email'),
    /** Phase 6.6: the canonical display name; null until onboarding asks. */
    displayName: text('display_name'),
    timezone: text('timezone').notNull().default('Asia/Kolkata'),
    locale: text('locale').notNull().default('en-IN'),
    createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
    /** Phase 19 (ADR-027): premium from this moment until revoked (null). Admins are premium by role, not here. */
    premiumSince: timestamp('premium_since', { withTimezone: true }),
    premiumGrantedBy: uuid('premium_granted_by').references((): AnyPgColumn => users.id, { onDelete: 'set null' }),
    /** Phase 19: one of the ten drawn profile pictures (contracts AVATARS); null = initials. */
    avatarId: text('avatar_id'),
    /**
     * After beta 4.6 (owner 2026-10-30): every streak and running theme, app
     * icon, picture and rim can be chosen, for testing; set in the admin
     * panel (audited). Badges and streaks stay what was earned.
     */
    rewardsUnlocked: boolean('rewards_unlocked').notNull().default(false),
  },
  (t) => [
    check('users_avatar_id', sql`${t.avatarId} is null or ${t.avatarId} in ('dumbbell', 'runner', 'yoga', 'cyclist', 'swimmer', 'boxer', 'hiker', 'crown', 'flame', 'trophy', 'spark', 'century')`),
    // Case-insensitive lookup by email for support tooling (§20). Not unique:
    // Firebase permits the same email across providers in some configurations,
    // and uniqueness is Firebase's job, not ours.
    index('users_email_idx').on(sql`lower(${t.email})`),
  ],
);

export type UserRow = typeof users.$inferSelect;
export type NewUserRow = typeof users.$inferInsert;
