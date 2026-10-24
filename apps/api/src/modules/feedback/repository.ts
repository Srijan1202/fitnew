/**
 * Feedback (Phase 19, ADR-026): the rows, and the audit entries an admin's
 * status or priority change writes in the same transaction (§20). Beta 3.6:
 * the pictures, the replies and the sender's own view.
 */
import { and, count, desc, eq, inArray, isNull, lt, ne } from 'drizzle-orm';
import type { FeedbackCategory, FeedbackDevice, FeedbackPictureType, FeedbackPriority, FeedbackStatus } from '@fitos/contracts';

import type { DatabaseHandle } from '../../db/client.js';
import { auditLogs, feedback, feedbackPictures, feedbackReplies, pushTokens } from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export class FeedbackRepository {
  constructor(private readonly db: Db) {}

  async inTransaction<T>(fn: (repo: FeedbackRepository) => Promise<T>): Promise<T> {
    return this.db.transaction(async (tx) => fn(new FeedbackRepository(tx as unknown as Db)));
  }

  async insert(row: {
    userId: string;
    category: FeedbackCategory;
    message: string;
    appVersion: string;
    device: FeedbackDevice | null;
    pictures: readonly { type: FeedbackPictureType; data: Buffer }[];
  }) {
    return this.inTransaction(async (tx) => {
      const [r] = await tx.db
        .insert(feedback)
        .values({
          userId: row.userId,
          category: row.category,
          message: row.message,
          appVersion: row.appVersion,
          deviceModel: row.device?.model ?? null,
          deviceOs: row.device?.os ?? null,
          screen: row.device?.screen ?? null,
        })
        .returning({ id: feedback.id, createdAt: feedback.createdAt });
      if (row.pictures.length > 0) {
        await tx.db.insert(feedbackPictures).values(
          row.pictures.map((p, i) => ({ feedbackId: r!.id, position: i, contentType: p.type, bytes: p.data.length, data: p.data })),
        );
      }
      return r!;
    });
  }

  async page(
    status: FeedbackStatus | 'open' | undefined,
    priority: FeedbackPriority | 'none' | undefined,
    category: FeedbackCategory | undefined,
    limit: number,
    before: Date | null,
  ) {
    const where = and(
      status === undefined ? undefined : status === 'open' ? ne(feedback.status, 'done') : eq(feedback.status, status),
      priority === undefined ? undefined : priority === 'none' ? isNull(feedback.priority) : eq(feedback.priority, priority),
      category === undefined ? undefined : eq(feedback.category, category),
      before === null ? undefined : lt(feedback.createdAt, before),
    );
    return this.db.select().from(feedback).where(where).orderBy(desc(feedback.createdAt), desc(feedback.id)).limit(limit);
  }

  /** The pictures (without their bytes) of these messages. */
  async picturesOf(ids: readonly string[]) {
    if (ids.length === 0) return [];
    return this.db
      .select({ id: feedbackPictures.id, feedbackId: feedbackPictures.feedbackId, type: feedbackPictures.contentType, bytes: feedbackPictures.bytes })
      .from(feedbackPictures)
      .where(inArray(feedbackPictures.feedbackId, [...ids]))
      .orderBy(feedbackPictures.feedbackId, feedbackPictures.position);
  }

  async repliesOf(ids: readonly string[]) {
    if (ids.length === 0) return [];
    return this.db
      .select()
      .from(feedbackReplies)
      .where(inArray(feedbackReplies.feedbackId, [...ids]))
      .orderBy(feedbackReplies.createdAt, feedbackReplies.id);
  }

  /** One picture with its bytes. */
  async picture(feedbackId: string, pictureId: string) {
    const [r] = await this.db
      .select({ type: feedbackPictures.contentType, data: feedbackPictures.data })
      .from(feedbackPictures)
      .where(and(eq(feedbackPictures.id, pictureId), eq(feedbackPictures.feedbackId, feedbackId)))
      .limit(1);
    return r ?? null;
  }

  /** How many rows per status and tag. */
  async counts() {
    return this.db
      .select({ status: feedback.status, priority: feedback.priority, n: count() })
      .from(feedback)
      .groupBy(feedback.status, feedback.priority);
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

  async insertReply(row: { feedbackId: string; adminUserId: string | null; message: string }) {
    const [r] = await this.db.insert(feedbackReplies).values(row).returning();
    return r!;
  }

  /** The sender's own messages, newest first. */
  async mine(userId: string, limit: number) {
    return this.db.select().from(feedback).where(eq(feedback.userId, userId)).orderBy(desc(feedback.createdAt), desc(feedback.id)).limit(limit);
  }

  /** Marks every reply to this sender read; how many were unread. */
  async markRead(userId: string, at: Date): Promise<number> {
    const mine = this.db.select({ id: feedback.id }).from(feedback).where(eq(feedback.userId, userId));
    const rows = await this.db
      .update(feedbackReplies)
      .set({ readAt: at })
      .where(and(inArray(feedbackReplies.feedbackId, mine), isNull(feedbackReplies.readAt)))
      .returning({ id: feedbackReplies.id });
    return rows.length;
  }

  /** Pictures sent before [before] are deleted (the text stays); how many. */
  async purgePictures(before: Date): Promise<number> {
    const rows = await this.db.delete(feedbackPictures).where(lt(feedbackPictures.createdAt, before)).returning({ id: feedbackPictures.id });
    return rows.length;
  }

  async tokensOf(userId: string): Promise<string[]> {
    return (await this.db.select({ token: pushTokens.token }).from(pushTokens).where(eq(pushTokens.userId, userId))).map((r) => r.token);
  }

  async removeTokens(tokens: readonly string[]): Promise<void> {
    if (tokens.length > 0) await this.db.delete(pushTokens).where(inArray(pushTokens.token, [...tokens]));
  }

  async audit(e: { actorUserId: string | null; action: string; entity: string; entityId: string; metadata: Record<string, unknown> }) {
    await this.db.insert(auditLogs).values(e);
  }
}
