/**
 * Feedback (Phase 19, ADR-026): the rows, and the audit entry an admin's
 * status change writes in the same transaction (§20).
 */
import { and, desc, eq, lt } from 'drizzle-orm';
import type { FeedbackCategory, FeedbackStatus } from '@fitos/contracts';

import type { DatabaseHandle } from '../../db/client.js';
import { auditLogs, feedback } from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export class FeedbackRepository {
  constructor(private readonly db: Db) {}

  async inTransaction<T>(fn: (repo: FeedbackRepository) => Promise<T>): Promise<T> {
    return this.db.transaction(async (tx) => fn(new FeedbackRepository(tx as unknown as Db)));
  }

  async insert(row: { userId: string; category: FeedbackCategory; message: string; appVersion: string }) {
    const [r] = await this.db.insert(feedback).values(row).returning({ id: feedback.id, createdAt: feedback.createdAt });
    return r!;
  }

  async page(status: FeedbackStatus | undefined, limit: number, before: Date | null) {
    const where = and(status === undefined ? undefined : eq(feedback.status, status), before === null ? undefined : lt(feedback.createdAt, before));
    return this.db.select().from(feedback).where(where).orderBy(desc(feedback.createdAt), desc(feedback.id)).limit(limit);
  }

  async setStatus(id: string, status: FeedbackStatus) {
    const [r] = await this.db.update(feedback).set({ status }).where(eq(feedback.id, id)).returning();
    return r ?? null;
  }

  async audit(e: { actorUserId: string | null; action: string; entity: string; entityId: string; metadata: Record<string, unknown> }) {
    await this.db.insert(auditLogs).values(e);
  }
}
