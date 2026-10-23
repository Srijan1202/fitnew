/**
 * Premium (Phase 19, ADR-027): the user's mark, their requests, and the
 * admin's decisions, each written with its audit row in one transaction.
 */
import { and, asc, desc, eq, isNotNull, sql } from 'drizzle-orm';

import type { DatabaseHandle } from '../../db/client.js';
import { auditLogs, premiumRequests, userRewards, users } from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export class PremiumRepository {
  constructor(private readonly db: Db) {}

  async inTransaction<T>(fn: (repo: PremiumRepository) => Promise<T>): Promise<T> {
    return this.db.transaction(async (tx) => fn(new PremiumRepository(tx as unknown as Db)));
  }

  async premiumSince(userId: string): Promise<Date | null> {
    const [u] = await this.db.select({ since: users.premiumSince }).from(users).where(eq(users.id, userId)).limit(1);
    return u?.since ?? null;
  }

  async latestRequest(userId: string) {
    const [r] = await this.db
      .select()
      .from(premiumRequests)
      .where(eq(premiumRequests.userId, userId))
      .orderBy(desc(premiumRequests.createdAt), desc(premiumRequests.id))
      .limit(1);
    return r ?? null;
  }

  /** Null when a pending request already exists (the partial unique index). */
  async createRequest(userId: string, message: string | null) {
    const [r] = await this.db.insert(premiumRequests).values({ userId, message }).onConflictDoNothing().returning();
    return r ?? null;
  }

  async requests(status: string | undefined, limit: number) {
    return this.db
      .select({
        request: premiumRequests,
        email: users.email,
        displayName: users.displayName,
        premiumSince: users.premiumSince,
      })
      .from(premiumRequests)
      .innerJoin(users, eq(users.id, premiumRequests.userId))
      .where(status === undefined ? undefined : eq(premiumRequests.status, status))
      .orderBy(desc(premiumRequests.createdAt), desc(premiumRequests.id))
      .limit(limit);
  }

  async requestById(id: string) {
    const [r] = await this.db.select().from(premiumRequests).where(eq(premiumRequests.id, id)).limit(1);
    return r ?? null;
  }

  /** Pending → approved or denied, once. Null when it was not pending. */
  async decide(id: string, status: 'approved' | 'denied', note: string | null, actor: string | null) {
    const [r] = await this.db
      .update(premiumRequests)
      .set({ status, note, decidedAt: sql`now()`, decidedBy: actor })
      .where(and(eq(premiumRequests.id, id), eq(premiumRequests.status, 'pending')))
      .returning();
    return r ?? null;
  }

  async grant(userId: string, actor: string | null): Promise<void> {
    await this.db
      .update(users)
      .set({ premiumSince: sql`coalesce(${users.premiumSince}, now())`, premiumGrantedBy: sql`coalesce(${users.premiumGrantedBy}, ${actor})` })
      .where(eq(users.id, userId));
  }

  /** Premium off, and a premium-only picture back to none. True when they were premium. */
  async revoke(userId: string, premiumAvatars: readonly string[]): Promise<boolean> {
    const [r] = await this.db
      .update(users)
      .set({
        premiumSince: null,
        premiumGrantedBy: null,
        avatarId: sql`case when ${users.avatarId} in (${sql.join(premiumAvatars.map((a) => sql`${a}`), sql`, `)}) then null else ${users.avatarId} end`,
      })
      .where(and(eq(users.id, userId), isNotNull(users.premiumSince)))
      .returning({ id: users.id });
    return r !== undefined;
  }

  async members() {
    // Qualified by hand: inside the subquery an unqualified column would be g's own.
    const granter = sql<string | null>`(select g.email from users g where g.id = "users"."premium_granted_by")`;
    return this.db
      .select({ userId: users.id, email: users.email, displayName: users.displayName, since: users.premiumSince, grantedBy: granter })
      .from(users)
      .where(isNotNull(users.premiumSince))
      .orderBy(desc(users.premiumSince));
  }

  /** Beta 3.4: the streak rewards this person earned, oldest first. */
  async rewards(userId: string): Promise<{ reward: string; earnedAt: Date }[]> {
    return this.db
      .select({ reward: userRewards.reward, earnedAt: userRewards.earnedAt })
      .from(userRewards)
      .where(eq(userRewards.userId, userId))
      .orderBy(asc(userRewards.earnedAt), asc(userRewards.reward));
  }

  async setAvatar(userId: string, avatarId: string | null): Promise<void> {
    await this.db.update(users).set({ avatarId, updatedAt: sql`now()` }).where(eq(users.id, userId));
  }


  async audit(e: { actorUserId: string | null; action: string; entity: string; entityId: string; metadata: Record<string, unknown> }) {
    await this.db.insert(auditLogs).values(e);
  }
}
