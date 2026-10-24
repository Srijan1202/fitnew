/**
 * Feedback (Phase 19, MASTER-SPEC §31 "feedback channel", ADR-026): testers
 * send a message from the app; the owner reads it in the admin panel and
 * marks it read or done, and tags it red, yellow or green (what to solve
 * first). Each change is audited like every admin action.
 *
 * Beta 3.6 (owner): up to three pictures (checked to be images; deleted
 * after six months), the phone when the sender leaves it in, and replies
 * from an admin, which the sender reads in the app and is told about by a
 * notification.
 */
import {
  FEEDBACK_PICTURE_DAYS,
  FEEDBACK_PICTURE_MAX_BYTES,
  type AdminFeedbackCounts,
  type AdminFeedbackItem,
  type AdminFeedbackList,
  type FeedbackCategory,
  type FeedbackPictureType,
  type FeedbackPriority,
  type FeedbackReply,
  type FeedbackStatus,
  type MyFeedbackList,
  type SendFeedbackRequest,
  type UpdateFeedbackRequest,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { PushSender } from '../../lib/push.js';
import type { FeedbackRepository } from './repository.js';

type Row = Awaited<ReturnType<FeedbackRepository['page']>>[number];
type PictureRow = Awaited<ReturnType<FeedbackRepository['picturesOf']>>[number];
type ReplyRow = Awaited<ReturnType<FeedbackRepository['repliesOf']>>[number];

function reply(r: ReplyRow): FeedbackReply {
  return { id: r.id, message: r.message, createdAt: r.createdAt.toISOString(), readAt: r.readAt?.toISOString() ?? null };
}

function item(r: Row, pictures: readonly PictureRow[], replies: readonly ReplyRow[]): AdminFeedbackItem {
  return {
    id: r.id,
    userId: r.userId,
    category: r.category as AdminFeedbackItem['category'],
    message: r.message,
    appVersion: r.appVersion,
    status: r.status as FeedbackStatus,
    priority: r.priority as FeedbackPriority | null,
    createdAt: r.createdAt.toISOString(),
    device: r.deviceModel !== null && r.deviceOs !== null ? { model: r.deviceModel, os: r.deviceOs, screen: r.screen } : null,
    pictures: pictures.filter((p) => p.feedbackId === r.id).map((p) => ({ id: p.id, type: p.type as FeedbackPictureType, bytes: p.bytes })),
    replies: replies.filter((x) => x.feedbackId === r.id).map(reply),
  };
}

/** Whether [data] starts like an image of [type] (the phone says; this checks). */
function looksLike(type: FeedbackPictureType, data: Buffer): boolean {
  switch (type) {
    case 'image/jpeg':
      return data.length > 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff;
    case 'image/png':
      return data.length > 8 && data.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
    case 'image/webp':
      return data.length > 12 && data.subarray(0, 4).toString('latin1') === 'RIFF' && data.subarray(8, 12).toString('latin1') === 'WEBP';
  }
}

const DAY_MS = 24 * 60 * 60 * 1000;

export class FeedbackService {
  constructor(
    private readonly repo: FeedbackRepository,
    private readonly push: PushSender,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async send(userId: string, body: SendFeedbackRequest): Promise<{ id: string; createdAt: string }> {
    const pictures = (body.pictures ?? []).map((p, i) => {
      const data = Buffer.from(p.data, 'base64');
      if (data.length === 0 || data.length > FEEDBACK_PICTURE_MAX_BYTES) {
        throw new AppError('VALIDATION_FAILED', 'Each picture can be at most 1 MB.', [{ path: `pictures.${i}`, issue: 'too-large' }]);
      }
      if (!looksLike(p.type, data)) {
        throw new AppError('VALIDATION_FAILED', 'That is not a picture FITOS can show.', [{ path: `pictures.${i}`, issue: 'not-an-image' }]);
      }
      return { type: p.type, data };
    });
    const r = await this.repo.insert({
      userId,
      category: body.category,
      message: body.message,
      appVersion: body.appVersion,
      device: body.device ?? null,
      pictures,
    });
    return { id: r.id, createdAt: r.createdAt.toISOString() };
  }

  async page(
    status: FeedbackStatus | 'open' | undefined,
    priority: FeedbackPriority | 'none' | undefined,
    category: FeedbackCategory | undefined,
    limit: number,
    before?: string,
  ): Promise<AdminFeedbackList> {
    const rows = await this.repo.page(status, priority, category, limit, before === undefined ? null : new Date(before));
    const ids = rows.map((r) => r.id);
    const [pictures, replies] = await Promise.all([this.repo.picturesOf(ids), this.repo.repliesOf(ids)]);
    return { items: rows.map((r) => item(r, pictures, replies)), next: rows.length === limit ? rows.at(-1)!.createdAt.toISOString() : null };
  }

  /** What is waiting: open feedback not tagged yet, open feedback per tag, and done. */
  async counts(): Promise<AdminFeedbackCounts> {
    const counts: AdminFeedbackCounts = { untagged: 0, red: 0, yellow: 0, green: 0, done: 0 };
    for (const r of await this.repo.counts()) {
      if (r.status === 'done') counts.done += r.n;
      else counts[(r.priority as FeedbackPriority | null) ?? 'untagged'] += r.n;
    }
    return counts;
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
    const [pictures, replies] = await Promise.all([this.repo.picturesOf([row.id]), this.repo.repliesOf([row.id])]);
    return item(row, pictures, replies);
  }

  /** One picture's bytes, for the admin panel. */
  async picture(feedbackId: string, pictureId: string): Promise<{ type: string; data: Buffer }> {
    const p = await this.repo.picture(feedbackId, pictureId);
    if (p === null) throw new AppError('NOT_FOUND', 'No such picture (pictures are deleted after six months).');
    return p;
  }

  /**
   * An admin's reply: stored and audited, then the sender's phones are told
   * ("FITOS replied to your feedback"). A failed push never fails the reply:
   * the sender sees it the next time they open their messages.
   */
  async reply(actor: string | null, id: string, message: string): Promise<{ reply: FeedbackReply; pushed: number }> {
    const saved = await this.repo.inTransaction(async (tx) => {
      const f = await tx.get(id);
      if (f === null) return null;
      const r = await tx.insertReply({ feedbackId: id, adminUserId: actor, message });
      await tx.audit({ actorUserId: actor, action: 'feedback.reply', entity: 'feedback', entityId: id, metadata: { replyId: r.id } });
      return { r, userId: f.userId };
    });
    if (saved === null) throw new AppError('NOT_FOUND', 'No such feedback.');
    let pushed = 0;
    const tokens = await this.repo.tokensOf(saved.userId);
    if (tokens.length > 0) {
      try {
        const result = await this.push.send(tokens, {
          title: 'FITOS replied to your feedback',
          body: message.length > 120 ? `${message.slice(0, 117)}…` : message,
          data: { type: 'feedback-reply', feedbackId: id },
        });
        pushed = result.sent;
        await this.repo.removeTokens(result.invalid);
      } catch {
        // The reply is saved; the app shows it when opened.
      }
    }
    return { reply: reply(saved.r), pushed };
  }

  /** The sender's own messages with their replies, and how many replies are unread. */
  async mine(userId: string): Promise<MyFeedbackList> {
    const rows = await this.repo.mine(userId, 50);
    const ids = rows.map((r) => r.id);
    const [pictures, replies] = await Promise.all([this.repo.picturesOf(ids), this.repo.repliesOf(ids)]);
    return {
      items: rows.map((r) => ({
        id: r.id,
        category: r.category as FeedbackCategory,
        message: r.message,
        status: r.status as FeedbackStatus,
        createdAt: r.createdAt.toISOString(),
        pictures: pictures.filter((p) => p.feedbackId === r.id).length,
        replies: replies.filter((x) => x.feedbackId === r.id).map(reply),
      })),
      unread: replies.filter((x) => x.readAt === null).length,
    };
  }

  async markRead(userId: string): Promise<{ unread: 0 }> {
    await this.repo.markRead(userId, this.now());
    return { unread: 0 };
  }

  /** Pictures older than FEEDBACK_PICTURE_DAYS are deleted; the text stays. */
  async purgeOldPictures(): Promise<number> {
    return this.repo.purgePictures(new Date(this.now().getTime() - FEEDBACK_PICTURE_DAYS * DAY_MS));
  }
}
