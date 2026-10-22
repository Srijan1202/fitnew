/**
 * Feedback (Phase 19, ADR-026): the rows, and the audit entries an admin's
 * status or priority change writes in the same transaction (§20).
 */
import { and, desc, eq, isNull, lt } from 'drizzle-orm';
import type { FeedbackCategory, FeedbackPriority, FeedbackStatus } from '@fitos/contracts';

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

  async page(status: FeedbackStatus | undefined, priority: FeedbackPriority | 'none' | undefined, limit: number, before: Date | null) {
    const where = and(
      status === undefined ? undefined : eq(feedback.status, status),
      priority === undefined ? undefined : priority === 'none' ? isNull(feedback.priority) : eq(feedback.priority, priority),
      before === null ? undefined : lt(feedback.createdAt, before),
    );
    return this.db.select().from(feedback).where(where).orderBy(desc(feedback.createdAt), desc(feedback.id)).limit(limit);
  }

  /** Locked until the transaction ends, so a concurrent change waits. */
  async get(id: string) {
    const [r] = await this.db.select().from(feedback).where(eq(feedback.id, id)).limit(1).for('update');
    return r ?? null;
  }

  async update(id: string, change: { status?: FeedbackStatus; priority?: FeedbackPriority | null }) {
    const [r] = await this.db.update(feedback).set(change).where(eq(feedback.id, id)).returning();
    return r ?? null;
  }

  async audit(e: { actorUserId: string | null; action: string; entity: string; entityId: string; metadata: Record<string, unknown> }) {
    await this.db.insert(auditLogs).values(e);
  }
}
