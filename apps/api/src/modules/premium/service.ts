/**
 * Premium (Phase 19, ADR-027; owner 2026-10-22). Premium is the admin role, or
 * an approval that lasts until revoked. It unlocks FITOS AI (with higher
 * limits), the weekly report, the colour themes and three profile pictures.
 */
import {
  PREMIUM_AVATAR_IDS,
  REWARD_AVATAR_IDS,
  RUNNING_BADGES,
  RUNNING_BADGES_MIN_BUILD,
  STREAK_REWARDS,
  type AdminPremiumMember,
  type AdminPremiumRequest,
  type PremiumRequest,
  type PremiumStatus,
  type RewardId,
  type RewardsResponse,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { PremiumRepository } from './repository.js';

type RequestRow = NonNullable<Awaited<ReturnType<PremiumRepository['latestRequest']>>>;

function requestOut(r: RequestRow): PremiumRequest {
  return {
    id: r.id,
    status: r.status as PremiumRequest['status'],
    message: r.message,
    createdAt: r.createdAt.toISOString(),
    decidedAt: r.decidedAt?.toISOString() ?? null,
    note: r.note,
  };
}

/** The token's claims say admin: premium by role, nothing stored. */
export const isAdminClaims = (claims: Readonly<Record<string, unknown>> | undefined): boolean => claims?.['role'] === 'admin';

export const premiumRequired = (what: string): AppError =>
  new AppError('FORBIDDEN', `${what} is part of FITOS Premium. Ask for it in Profile → Premium.`, [{ path: 'premium', issue: 'premium-required' }]);

export class PremiumService {
  /**
   * [awardBadges]: beta 4.2, records the running distance firsts before the
   * rewards are read (EffortsRepository.awardBadges); absent where only
   * premium status is needed.
   */
  constructor(
    private readonly repo: PremiumRepository,
    private readonly awardBadges?: (userId: string) => Promise<unknown>,
  ) {}

  async isPremium(userId: string, claims: Readonly<Record<string, unknown>> | undefined): Promise<boolean> {
    if (isAdminClaims(claims)) return true;
    return (await this.repo.premiumSince(userId)) !== null;
  }

  async status(userId: string, claims: Readonly<Record<string, unknown>> | undefined): Promise<PremiumStatus> {
    const [since, latest] = await Promise.all([this.repo.premiumSince(userId), this.repo.latestRequest(userId)]);
    const admin = isAdminClaims(claims);
    return {
      premium: admin || since !== null,
      source: since !== null ? 'granted' : admin ? 'admin' : null,
      since: since?.toISOString() ?? null,
      request: latest === null ? null : requestOut(latest),
    };
  }

  async request(userId: string, claims: Readonly<Record<string, unknown>> | undefined, message: string | undefined): Promise<PremiumRequest> {
    if (await this.isPremium(userId, claims)) throw new AppError('CONFLICT', 'You already have FITOS Premium.');
    const text = message === undefined || message === '' ? null : message;
    const r = await this.repo.createRequest(userId, text);
    if (r === null) throw new AppError('CONFLICT', 'Your request is already waiting for an answer.');
    return requestOut(r);
  }

  async setAvatar(userId: string, claims: Readonly<Record<string, unknown>> | undefined, avatarId: string | null): Promise<{ avatarId: string | null }> {
    if (avatarId !== null && PREMIUM_AVATAR_IDS.includes(avatarId) && !(await this.isPremium(userId, claims))) {
      throw premiumRequired('This picture');
    }
    // Beta 3.4: a streak picture only once its streak was reached.
    if (avatarId !== null && REWARD_AVATAR_IDS.includes(avatarId) && !(await this.rewards(userId)).earned.some((r) => r.id === avatarId)) {
      const reward = STREAK_REWARDS.find((r) => r.id === avatarId)!;
      throw new AppError('FORBIDDEN', `Reach a ${reward.days}-day streak to unlock this picture.`, [{ path: 'avatarId', issue: 'reward-locked' }]);
    }
    await this.repo.setAvatar(userId, avatarId);
    return { avatarId };
  }

  /**
   * Beta 3.4: streak rewards earned (readable whether or not streaks are
   * switched on). Beta 4.2: and the running distance firsts, checked first
   * so past runs count — sent only to builds that read them ([appBuild] ≥
   * RUNNING_BADGES_MIN_BUILD): older phones check the ids strictly.
   */
  async rewards(userId: string, appBuild: number | null = null): Promise<RewardsResponse> {
    const badges = appBuild !== null && appBuild >= RUNNING_BADGES_MIN_BUILD;
    if (badges) await this.awardBadges?.(userId);
    const rows = await this.repo.rewards(userId);
    const known = (id: string): id is RewardId =>
      STREAK_REWARDS.some((x) => x.id === id) || (badges && RUNNING_BADGES.some((x) => x.id === id));
    return {
      earned: rows
        .filter((r): r is { reward: RewardId; earnedAt: Date } => known(r.reward))
        .map((r) => ({ id: r.reward, earnedAt: r.earnedAt.toISOString() })),
    };
  }

  /* -------------------------------------------------------------- admin -- */

  async requests(status: string | undefined, limit: number): Promise<{ items: AdminPremiumRequest[] }> {
    const rows = await this.repo.requests(status, limit);
    return {
      items: rows.map((r) => ({
        ...requestOut(r.request),
        userId: r.request.userId,
        email: r.email,
        displayName: r.displayName,
        userPremium: r.premiumSince !== null,
      })),
    };
  }

  async decide(actor: string | null, id: string, decision: 'approve' | 'deny', note: string | undefined): Promise<PremiumRequest> {
    const row = await this.repo.inTransaction(async (tx) => {
      const before = await tx.requestById(id);
      if (before === null) return 'missing' as const;
      const r = await tx.decide(id, decision === 'approve' ? 'approved' : 'denied', note === undefined || note === '' ? null : note, actor);
      if (r === null) return 'decided' as const;
      if (decision === 'approve') await tx.grant(r.userId, actor);
      await tx.audit({
        actorUserId: actor,
        action: decision === 'approve' ? 'premium.approve' : 'premium.deny',
        entity: 'user',
        entityId: r.userId,
        metadata: { requestId: id, note: r.note },
      });
      return r;
    });
    if (row === 'missing') throw new AppError('NOT_FOUND', 'No such request.');
    if (row === 'decided') throw new AppError('CONFLICT', 'This request was already answered.');
    return requestOut(row);
  }

  async members(): Promise<{ items: AdminPremiumMember[] }> {
    const rows = await this.repo.members();
    return { items: rows.map((r) => ({ userId: r.userId, email: r.email, displayName: r.displayName, since: r.since!.toISOString(), grantedBy: r.grantedBy })) };
  }

  async revoke(actor: string | null, userId: string): Promise<void> {
    const done = await this.repo.inTransaction(async (tx) => {
      const was = await tx.revoke(userId, PREMIUM_AVATAR_IDS);
      if (was) await tx.audit({ actorUserId: actor, action: 'premium.revoke', entity: 'user', entityId: userId, metadata: {} });
      return was;
    });
    if (!done) throw new AppError('NOT_FOUND', 'This user does not have premium (admins are premium by role and cannot be revoked here).');
  }
}
