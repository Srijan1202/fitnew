/**
 * Feedback (Phase 19, MASTER-SPEC §31 "feedback channel", ADR-026): testers
 * send a message from the app; the owner reads it in the admin panel and
 * marks it read or done, and tags it red, yellow or green (what to solve
 * first). Each change is audited like every admin action.
 */
import type { AdminFeedbackItem, AdminFeedbackList, FeedbackPriority, FeedbackStatus, SendFeedbackRequest, UpdateFeedbackRequest } from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { FeedbackRepository } from './repository.js';

type Row = Awaited<ReturnType<FeedbackRepository['page']>>[number];

function item(r: Row): AdminFeedbackItem {
  return {
    id: r.id,
    userId: r.userId,
    category: r.category as AdminFeedbackItem['category'],
    message: r.message,
    appVersion: r.appVersion,
    status: r.status as FeedbackStatus,
    priority: r.priority as FeedbackPriority | null,
    createdAt: r.createdAt.toISOString(),
  };
}

export class FeedbackService {
  constructor(private readonly repo: FeedbackRepository) {}

  async send(userId: string, body: SendFeedbackRequest): Promise<{ id: string; createdAt: string }> {
    const r = await this.repo.insert({ userId, category: body.category, message: body.message, appVersion: body.appVersion });
    return { id: r.id, createdAt: r.createdAt.toISOString() };
  }

  async page(status: FeedbackStatus | undefined, priority: FeedbackPriority | 'none' | undefined, limit: number, before?: string): Promise<AdminFeedbackList> {
    const rows = await this.repo.page(status, priority, limit, before === undefined ? null : new Date(before));
    return { items: rows.map(item), next: rows.length === limit ? rows.at(-1)!.createdAt.toISOString() : null };
  }

  /** A status, a priority, or both; one audit row per field that changed. Setting the same value again changes and records nothing. */
  async update(actor: string | null, id: string, change: UpdateFeedbackRequest): Promise<AdminFeedbackItem> {
    const row = await this.repo.inTransaction(async (tx) => {
      const before = await tx.get(id);
      if (before === null) return null;
      const set: { status?: FeedbackStatus; priority?: FeedbackPriority | null } = {};
      if (change.status !== undefined && change.status !== before.status) set.status = change.status;
      if (change.priority !== undefined && change.priority !== before.priority) set.priority = change.priority;
      if (Object.keys(set).length === 0) return before;
      const r = await tx.update(id, set);
      if (set.status !== undefined) {
        await tx.audit({ actorUserId: actor, action: 'feedback.status', entity: 'feedback', entityId: id, metadata: { status: set.status } });
      }
      if (set.priority !== undefined) {
        await tx.audit({ actorUserId: actor, action: 'feedback.priority', entity: 'feedback', entityId: id, metadata: { priority: set.priority, from: before.priority } });
      }
      return r;
    });
    if (row === null) throw new AppError('NOT_FOUND', 'No such feedback.');
    return item(row);
  }
}
