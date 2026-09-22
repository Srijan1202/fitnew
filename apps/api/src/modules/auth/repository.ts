/**
 * users persistence. Drizzle queries only — no fitness rules, no identity
 * logic (§8.3). The one piece of cleverness is documented inline.
 */
import { eq, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import { userProfiles, users, type UserRow } from '../../db/schema.js';

export interface UpsertUserInput {
  readonly firebaseUid: string;
  readonly email: string | null;
  readonly timezone: string;
  readonly locale: string;
}

export interface UpsertUserResult {
  readonly row: UserRow;
  /** True iff this call inserted the row rather than finding it. */
  readonly inserted: boolean;
}

export class UsersRepository {
  constructor(private readonly db: DatabaseHandle['db']) {}

  /**
   * Insert-or-fetch in ONE statement, so two first-sign-ins racing on the same
   * uid cannot both insert and cannot both believe they were first.
   *
   * On conflict we refresh `email` (Firebase is the source of truth for it)
   * and bump `updated_at`, but never touch `timezone`/`locale` — those are
   * the user's settings once the row exists, and a fresh device must not
   * clobber them.
   *
   * `(xmax = 0)` is Postgres' way of telling an inserted row from an updated
   * one in the same RETURNING clause: a freshly inserted tuple has no
   * deleting transaction id. Plain Postgres, no extension (§28 portability).
   */
  async upsertByFirebaseUid(input: UpsertUserInput): Promise<UpsertUserResult> {
    const rows = await this.db
      .insert(users)
      .values({
        firebaseUid: input.firebaseUid,
        email: input.email,
        timezone: input.timezone,
        locale: input.locale,
      })
      .onConflictDoUpdate({
        target: users.firebaseUid,
        set: {
          email: sql`excluded.email`,
          updatedAt: sql`now()`,
        },
      })
      .returning({
        id: users.id,
        firebaseUid: users.firebaseUid,
        email: users.email,
        displayName: users.displayName,
        timezone: users.timezone,
        locale: users.locale,
        createdAt: users.createdAt,
        updatedAt: users.updatedAt,
        deletedAt: users.deletedAt,
        inserted: sql<boolean>`(xmax = 0)`,
      });

    const first = rows[0];
    if (first === undefined) {
      throw new Error('upsert returned no row — this should be impossible');
    }
    const { inserted, ...row } = first;
    return { row, inserted };
  }

  /** Next onboarding step for the session response; 'goal' when no profile row exists yet. */
  async onboardingStage(userId: string): Promise<string> {
    const [p] = await this.db
      .select({ stage: userProfiles.onboardingStage })
      .from(userProfiles)
      .where(eq(userProfiles.userId, userId))
      .limit(1);
    return p?.stage ?? 'goal';
  }
}
