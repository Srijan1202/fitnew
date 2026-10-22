/**
 * Feedback (Phase 19, MASTER-SPEC §31 "feedback channel", ADR-026): testers
 * send a message from the app; the owner reads it in the admin panel and
 * marks it read or done. A status change is audited like every admin action.
 */
import type { AdminFeedbackItem, AdminFeedbackList, FeedbackStatus, SendFeedbackRequest } from '@fitos/contracts';

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
    createdAt: r.createdAt.toISOString(),
  };
}

export class FeedbackService {
  constructor(private readonly repo: FeedbackRepository) {}

  async send(userId: string, body: SendFeedbackRequest): Promise<{ id: string; createdAt: string }> {
    const r = await this.repo.insert({ userId, category: body.category, message: body.message, appVersion: body.appVersion });
    return { id: r.id, createdAt: r.createdAt.toISOString() };
  }

  async page(status: FeedbackStatus | undefined, limit: number, before?: string): Promise<AdminFeedbackList> {
    const rows = await this.repo.page(status, limit, before === undefined ? null : new Date(before));
    return { items: rows.map(item), next: rows.length === limit ? rows.at(-1)!.createdAt.toISOString() : null };
  }

  async setStatus(actor: string | null, id: string, status: FeedbackStatus): Promise<AdminFeedbackItem> {
    const row = await this.repo.inTransaction(async (tx) => {
      const r = await tx.setStatus(id, status);
      if (r === null) return null;
      await tx.audit({ actorUserId: actor, action: 'feedback.status', entity: 'feedback', entityId: id, metadata: { status } });
      return r;
    });
    if (row === null) throw new AppError('NOT_FOUND', 'No such feedback.');
    return item(row);
  }
}
