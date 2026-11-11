/**
 * Community (beta 5.8, ADR-057): joining and leaving (the `community`
 * consent), friends, blocks, clubs, the boards and reports, and the week's
 * counts behind the boards. Nobody is seen until they join; a hidden or
 * blocking person is never seen; a board holds counts only.
 */
import { randomInt } from 'node:crypto';

import {
  CLUB_CODE_ALPHABET,
  COMMUNITY_HISTORY_WEEKS,
  COUNTED_RUN,
  COUNTED_SESSION,
  CURRENT_POLICY_VERSION,
  FRIEND_DECLINE_COOLDOWN_DAYS,
  MAX_CLUB_MEMBERS,
  MAX_CLUBS_JOINED,
  MAX_CLUBS_OWNED,
  MAX_FRIENDS,
  WORLD_BOARD_ROWS,
  handleProblem,
  type Board,
  type BoardMetric,
  type BoardRow,
  type Club,
  type CommunityMe,
  type CommunityPerson,
  type CommunityProfile,
  type FriendsResponse,
  type JoinCommunityRequest,
  type LastWeek,
  type PersonProfile,
  type ReportRequest,
  type WeekCounts,
  type UpdateCommunityRequest,
} from '@fitos/contracts';
import { boardKey, keptPlanPct, placesMoved, rankBy, type BoardMetricKey } from '@fitos/core/community/board';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';
import { isoWeekday } from '@fitos/core/progress/streak';

import { AppError } from '../../lib/errors.js';
import type { PushSender } from '../../lib/push.js';
import type { CommunityRepository, PersonRow, StatRow, WeekRow } from './repository.js';

/** The person's current streak (the progress service's own count). */
export type StreakOf = (userId: string) => Promise<number>;

/** Beta 6.2 (C11): training days planned from `from` to `to`; null without a programme. */
export type PlannedOf = (userId: string, from: string, to: string) => Promise<number | null>;

/** Past weeks kept per person (the profile shows 4; last week and the one before for "moved"). */
export const HISTORY_WEEKS_KEPT = 8;

const notJoined = (): AppError =>
  new AppError('FORBIDDEN', 'Join Community first.', [{ path: 'community', issue: 'not-joined' }]);

const handleRefused = (problem: 'format' | 'reserved' | 'word' | 'taken'): AppError =>
  problem === 'taken'
    ? new AppError('CONFLICT', 'That handle is taken.', [{ path: 'handle', issue: 'taken' }])
    : new AppError('VALIDATION_FAILED', problem === 'format' ? 'Use 3–20 letters, numbers or _.' : 'Choose another handle.', [{ path: 'handle', issue: problem }]);

const avatar = (id: string | null): CommunityPerson['avatarId'] => id as CommunityPerson['avatarId'];

const personOf = (p: PersonRow): CommunityPerson => ({ userId: p.userId, handle: p.handle, avatarId: avatar(p.avatarId), country: p.country });

/** A new club code: 8 of the unambiguous alphabet. */
export function newClubCode(): string {
  let out = '';
  for (let i = 0; i < 8; i++) out += CLUB_CODE_ALPHABET[randomInt(CLUB_CODE_ALPHABET.length)];
  return out;
}

const rowOf = (r: StatRow & { rank: number }, viewer: string): BoardRow => ({
  rank: r.rank,
  ...personOf(r),
  sessions: r.sessions,
  runM: r.runM,
  streak: r.streak,
  activeDays: r.activeDays,
  keptPct: r.keptPct,
  me: r.userId === viewer,
});

/** Best first by the metric (core rankBy: ties share a place, 1, 2, 2, 4). */
export function rankRows(rows: readonly StatRow[], metric: BoardMetric, viewer: string): BoardRow[] {
  return rankBy(rows, metric).map((r) => rowOf(r, viewer));
}

/** A stored week as a board row's counts. */
const statOf = (p: PersonRow, w: WeekRow): StatRow => ({
  ...p,
  sessions: w.sessions,
  runM: w.runM,
  streak: w.streak,
  activeDays: w.activeDays,
  keptPct: keptPlanPct(w.sessions, w.planned ?? 0),
});

const weekCountsOf = (w: WeekRow): WeekCounts => ({
  weekFrom: w.weekFrom,
  sessions: w.sessions,
  runM: w.runM,
  activeDays: w.activeDays,
  keptPct: keptPlanPct(w.sessions, w.planned ?? 0),
});

/** Something counted for this metric (the first key above zero). */
const counted = (metric: BoardMetricKey, r: StatRow): boolean => (boardKey(metric, r)[0] ?? 0) > 0;

export class CommunityService {
  constructor(
    private readonly repo: CommunityRepository,
    private readonly streakOf: StreakOf,
    private readonly push: PushSender,
    private readonly now: () => Date = () => new Date(),
    private readonly plannedOf: PlannedOf = async () => null,
  ) {}

  /* -------------------------------------------------------------- joining -- */

  private profileOf(p: { handle: string; avatarId: string | null; country: string | null; onWorld: boolean; createdAt: Date }): CommunityProfile {
    return { handle: p.handle, avatarId: avatar(p.avatarId), country: p.country, onWorld: p.onWorld, joinedAt: p.createdAt.toISOString() };
  }

  async me(userId: string): Promise<CommunityMe> {
    const p = await this.repo.profile(userId);
    return { profile: p === null ? null : this.profileOf(p), incoming: p === null ? 0 : await this.repo.incomingCount(userId) };
  }

  private async requireMember(userId: string) {
    const p = await this.repo.profile(userId);
    if (p === null) throw notJoined();
    return p;
  }

  private async checkHandle(handle: string, userId: string): Promise<void> {
    const problem = handleProblem(handle);
    if (problem !== null) throw handleRefused(problem);
    const owner = await this.repo.handleOwner(handle);
    if (owner !== null && owner !== userId) throw handleRefused('taken');
  }

  /** Joining is the `community` consent, to the current policy. */
  async join(userId: string, body: JoinCommunityRequest, ipHash: string | null): Promise<CommunityMe> {
    if (body.policyVersion !== CURRENT_POLICY_VERSION) {
      throw new AppError('CONFLICT', 'The privacy policy changed: read and accept the new one first.', [{ path: 'policyVersion', issue: 'outdated' }]);
    }
    if ((await this.repo.profile(userId)) !== null) throw new AppError('CONFLICT', 'Already in Community.', [{ path: 'community', issue: 'joined' }]);
    await this.checkHandle(body.handle, userId);
    const created = await this.repo.inTransaction(async (tx) => {
      const p = await tx.insertProfile(userId, body.handle, body.country, body.onWorld);
      if (p === null) return null;
      await tx.recordConsent(userId, true, CURRENT_POLICY_VERSION, ipHash);
      return p;
    });
    if (created === null) throw handleRefused('taken');
    await this.refreshOne(userId);
    return this.me(userId);
  }

  async update(userId: string, body: UpdateCommunityRequest): Promise<CommunityMe> {
    await this.requireMember(userId);
    if (body.handle !== undefined) await this.checkHandle(body.handle, userId);
    try {
      await this.repo.updateProfile(userId, body);
    } catch (e) {
      if (String((e as { code?: string }).code) === '23505') throw handleRefused('taken');
      throw e;
    }
    return this.me(userId);
  }

  /** Leaving withdraws the consent and removes the person from everything at once. */
  async leave(userId: string, ipHash: string | null): Promise<void> {
    await this.repo.inTransaction(async (tx) => {
      if ((await tx.profile(userId)) === null) return;
      await tx.leave(userId);
      await tx.recordConsent(userId, false, CURRENT_POLICY_VERSION, ipHash);
    });
  }

  /* --------------------------------------------------------------- people -- */

  async search(viewer: string, q: string): Promise<CommunityPerson[]> {
    await this.requireMember(viewer);
    const prefix = q.replace(/^@/, '').toLowerCase();
    if (!/^[a-z0-9_]{2,20}$/.test(prefix)) return [];
    return (await this.repo.search(viewer, prefix, 10)).map(personOf);
  }

  async friends(viewer: string): Promise<FriendsResponse> {
    await this.requireMember(viewer);
    const l = await this.repo.friendLists(viewer);
    return { friends: l.friends.map(personOf), incoming: l.incoming.map(personOf), outgoing: l.outgoing.map(personOf) };
  }

  private async tell(userId: string, title: string, body: string, data: Record<string, string>): Promise<void> {
    const tokens = await this.repo.pushTokens(userId);
    if (tokens.length === 0) return;
    try {
      const r = await this.push.send(tokens, { title, body, data });
      await this.repo.removeTokens(r.invalid);
    } catch {
      // The request is saved; the app shows it when opened.
    }
  }

  /** Ask by handle; when they had already asked you, you become friends. */
  async addFriend(viewer: string, handle: string): Promise<{ status: 'requested' | 'friends' }> {
    const me = await this.requireMember(viewer);
    const other = await this.repo.visibleByHandle(viewer, handle);
    if (other === null) throw new AppError('NOT_FOUND', 'No one in Community has that handle.');
    const existing = await this.repo.friendship(viewer, other.userId);
    if (existing?.status === 'accepted') return { status: 'friends' };
    if (existing !== null && existing.requesterId === other.userId) return this.accept(viewer, other.userId);
    if (existing !== null) return { status: 'requested' };
    // Beta 6.2 (S7): they declined lately; it looks sent, nothing is.
    const since = new Date(this.now().getTime() - FRIEND_DECLINE_COOLDOWN_DAYS * 86_400_000);
    if (await this.repo.declinedSince(viewer, other.userId, since)) return { status: 'requested' };
    if ((await this.repo.friendCount(viewer)) >= MAX_FRIENDS) {
      throw new AppError('CONFLICT', `${MAX_FRIENDS} friends is the most for now.`, [{ path: 'friends', issue: 'limit' }]);
    }
    await this.repo.request(viewer, other.userId);
    await this.tell(other.userId, 'New friend request', `@${me.handle} wants to be friends on FITOS.`, { type: 'community', screen: 'friends' });
    return { status: 'requested' };
  }

  async accept(viewer: string, requester: string): Promise<{ status: 'friends' }> {
    const me = await this.requireMember(viewer);
    if ((await this.repo.visible(viewer, requester)) === null || !(await this.repo.accept(requester, viewer))) {
      throw new AppError('NOT_FOUND', 'No such friend request.');
    }
    await this.repo.clearDeclines(viewer, requester);
    await this.tell(requester, 'Friend request accepted', `You and @${me.handle} are friends on FITOS.`, { type: 'community', screen: 'friends' });
    return { status: 'friends' };
  }

  /** Decline, cancel or unfriend: the same act. */
  async unfriend(viewer: string, other: string): Promise<void> {
    await this.requireMember(viewer);
    const f = await this.repo.friendship(viewer, other);
    await this.repo.unfriend(viewer, other);
    // Beta 6.2 (S7): declining a request starts the requester's cooldown.
    if (f?.status === 'pending' && f.addresseeId === viewer) await this.repo.recordDecline(other, viewer);
  }

  /** Beta 6.2 (C4, owner Q3): a friend's or club-mate's board data; 404 for anyone else. */
  async personProfile(viewer: string, userId: string): Promise<PersonProfile> {
    await this.requireMember(viewer);
    const p = userId === viewer ? null : await this.repo.visible(viewer, userId);
    if (p === null) throw new AppError('NOT_FOUND', 'No such member.');
    const [f, common] = await Promise.all([this.repo.friendship(viewer, userId), this.repo.clubsInCommon(viewer, userId)]);
    const friend = f?.status === 'accepted';
    if (!friend && common.length === 0) throw new AppError('NOT_FOUND', 'No such member.');
    await this.refreshOne(userId);
    const now = (await this.repo.stats(userId))!;
    const weeks = Array.from({ length: COMMUNITY_HISTORY_WEEKS }, (_, i) => addDays(now.weekFrom, -7 * (COMMUNITY_HISTORY_WEEKS - i)));
    const past = new Map((await this.repo.history([userId], weeks)).map((h) => [h.weekFrom, h]));
    const zero = (weekFrom: string): WeekRow => ({ weekFrom, sessions: 0, runM: 0, streak: 0, activeDays: 0, planned: null });
    return {
      person: personOf(p),
      relation: friend ? 'friend' : 'club-mate',
      friendsSince: friend && f.acceptedAt !== null ? f.acceptedAt.toISOString() : null,
      streak: now.streak,
      thisWeek: weekCountsOf(now),
      weeks: weeks.map((w) => weekCountsOf(past.get(w) ?? zero(w))),
      clubsInCommon: common,
    };
  }

  async block(viewer: string, other: string): Promise<void> {
    await this.requireMember(viewer);
    if (other === viewer) throw new AppError('VALIDATION_FAILED', 'You cannot block yourself.');
    await this.repo.inTransaction(async (tx) => {
      await tx.block(viewer, other);
      await tx.unfriend(viewer, other);
    });
  }

  async unblock(viewer: string, other: string): Promise<void> {
    await this.repo.unblock(viewer, other);
  }

  async blocked(viewer: string): Promise<CommunityPerson[]> {
    return (await this.repo.blocked(viewer)).map(personOf);
  }

  /* ---------------------------------------------------------------- clubs -- */

  private clubOf(c: { id: string; name: string; code: string; ownerId: string; members: number; createdAt: Date }, viewer: string): Club {
    return { id: c.id, name: c.name, code: c.code, members: c.members, mine: c.ownerId === viewer, createdAt: c.createdAt.toISOString() };
  }

  async clubs(viewer: string): Promise<Club[]> {
    await this.requireMember(viewer);
    return (await this.repo.clubsOf(viewer)).map((c) => this.clubOf(c, viewer));
  }

  async createClub(viewer: string, name: string): Promise<Club> {
    await this.requireMember(viewer);
    if ((await this.repo.ownedCount(viewer)) >= MAX_CLUBS_OWNED) {
      throw new AppError('CONFLICT', `You can make ${MAX_CLUBS_OWNED} clubs.`, [{ path: 'clubs', issue: 'owned-limit' }]);
    }
    if ((await this.repo.joinedCount(viewer)) >= MAX_CLUBS_JOINED) {
      throw new AppError('CONFLICT', `You can be in ${MAX_CLUBS_JOINED} clubs.`, [{ path: 'clubs', issue: 'joined-limit' }]);
    }
    for (let attempt = 0; attempt < 5; attempt++) {
      const id = await this.repo.inTransaction((tx) => tx.createClub(viewer, name, newClubCode()));
      if (id !== null) return this.clubOf((await this.repo.club(id))!, viewer);
    }
    throw new AppError('INTERNAL', 'Could not make a club code; try again.');
  }

  async joinClub(viewer: string, code: string): Promise<Club> {
    await this.requireMember(viewer);
    const club = await this.repo.clubByCode(code);
    if (club === null) throw new AppError('NOT_FOUND', 'No club has that code.');
    if (await this.repo.isMember(club.id, viewer)) return this.clubOf(club, viewer);
    if (await this.repo.blockedEitherWay(viewer, club.ownerId)) throw new AppError('NOT_FOUND', 'No club has that code.');
    if (await this.repo.isBanned(club.id, viewer)) {
      throw new AppError('FORBIDDEN', "The club's owner removed you from this club.", [{ path: 'clubs', issue: 'removed' }]);
    }
    if ((await this.repo.joinedCount(viewer)) >= MAX_CLUBS_JOINED) {
      throw new AppError('CONFLICT', `You can be in ${MAX_CLUBS_JOINED} clubs.`, [{ path: 'clubs', issue: 'joined-limit' }]);
    }
    if (club.members >= MAX_CLUB_MEMBERS) throw new AppError('CONFLICT', 'That club is full.', [{ path: 'clubs', issue: 'full' }]);
    await this.repo.joinClub(club.id, viewer);
    return this.clubOf((await this.repo.club(club.id))!, viewer);
  }

  /** Leaving a club you made passes it to its longest member (or deletes it when empty). */
  async leaveClub(viewer: string, clubId: string): Promise<void> {
    await this.repo.inTransaction((tx) => tx.leaveClub(clubId, viewer));
  }

  /* --------------------------------------- beta 6.2 (C5): the owner's tools -- */

  /** The club when the viewer owns it: 404 when they are not in it, 403 when they are but do not own it. */
  private async requireOwner(viewer: string, clubId: string) {
    await this.requireMember(viewer);
    const c = await this.repo.club(clubId);
    if (c === null || !(await this.repo.isMember(clubId, viewer))) throw new AppError('NOT_FOUND', 'No such club.');
    if (c.ownerId !== viewer) throw new AppError('FORBIDDEN', 'Only the club\'s owner can do that.', [{ path: 'clubs', issue: 'not-owner' }]);
    return c;
  }

  async renameClub(viewer: string, clubId: string, name: string): Promise<Club> {
    await this.requireOwner(viewer, clubId);
    await this.repo.renameClub(clubId, name);
    return this.clubOf((await this.repo.club(clubId))!, viewer);
  }

  /** A new code: the old one stops working at once. */
  async newClubCode(viewer: string, clubId: string): Promise<Club> {
    await this.requireOwner(viewer, clubId);
    for (let attempt = 0; attempt < 5; attempt++) {
      if (await this.repo.setClubCode(clubId, newClubCode())) return this.clubOf((await this.repo.club(clubId))!, viewer);
    }
    throw new AppError('INTERNAL', 'Could not make a club code; try again.');
  }

  /** Pass the club to another member; they are told. */
  async passClub(viewer: string, clubId: string, userId: string): Promise<Club> {
    const c = await this.requireOwner(viewer, clubId);
    if (userId === viewer || !(await this.repo.isMember(clubId, userId))) throw new AppError('NOT_FOUND', 'No such member in this club.');
    await this.repo.setClubOwner(clubId, userId);
    await this.tell(userId, 'A club is yours', `You now run ${c.name} on FITOS.`, { type: 'community', screen: 'clubs' });
    return this.clubOf((await this.repo.club(clubId))!, viewer);
  }

  /** Out, and kept out until let back (owner Q2). */
  async removeMember(viewer: string, clubId: string, userId: string): Promise<void> {
    await this.requireOwner(viewer, clubId);
    if (userId === viewer) throw new AppError('VALIDATION_FAILED', 'Pass the club to someone, or leave it.');
    if (!(await this.repo.isMember(clubId, userId))) throw new AppError('NOT_FOUND', 'No such member in this club.');
    await this.repo.inTransaction((tx) => tx.removeFromClub(clubId, userId));
  }

  async removedFrom(viewer: string, clubId: string): Promise<CommunityPerson[]> {
    await this.requireOwner(viewer, clubId);
    return (await this.repo.removedFrom(clubId)).map(personOf);
  }

  async letBack(viewer: string, clubId: string, userId: string): Promise<void> {
    await this.requireOwner(viewer, clubId);
    if (!(await this.repo.letBack(clubId, userId))) throw new AppError('NOT_FOUND', 'They were not removed from this club.');
  }

  /* --------------------------------------------------------------- boards -- */

  private async week(viewer: string): Promise<{ from: string; to: string }> {
    const tz = await this.repo.timezoneOf(viewer);
    const today = localDateOf(this.now(), tz);
    const from = addDays(today, 1 - isoWeekday(today));
    return { from, to: addDays(from, 6) };
  }

  private async board(viewer: string, metric: BoardMetric, rows: StatRow[]): Promise<Board> {
    const w = await this.week(viewer);
    const ranked = rankRows(rows, metric, viewer);
    // Beta 6.2 (C12): the same people, last week and the week before.
    const weeks = [addDays(w.from, -7), addDays(w.from, -14)];
    const people = new Map(rows.map((r) => [r.userId, r as PersonRow]));
    const past = await this.repo.history([...people.keys()], weeks);
    const at = (week: string) => past.filter((h) => h.weekFrom === week).map((h) => statOf(people.get(h.userId)!, h));
    return { metric, weekFrom: w.from, weekTo: w.to, rows: ranked, me: null, total: ranked.length, lastWeek: this.lastWeek(viewer, metric, weeks, at(weeks[0]!), at(weeks[1]!)) };
  }

  /**
   * Beta 6.2 (C12): last week's top three (only people who counted
   * something), the viewer's place, and the places moved since the week before.
   */
  private lastWeek(viewer: string, metric: BoardMetric, weeks: string[], last: StatRow[], before: StatRow[]): LastWeek | null {
    const lastRanked = rankBy(last, metric);
    const podium = lastRanked.filter((r) => r.rank <= 3 && counted(metric, r)).map((r) => rowOf(r, viewer));
    if (podium.length === 0) return null;
    const rankIn = (rs: (StatRow & { rank: number })[]) => rs.find((r) => r.userId === viewer)?.rank ?? null;
    const myRank = rankIn(lastRanked);
    return { weekFrom: weeks[0]!, podium, myRank, moved: placesMoved(rankIn(rankBy(before, metric)), myRank) };
  }

  async friendsBoard(viewer: string, metric: BoardMetric): Promise<Board> {
    await this.requireMember(viewer);
    await this.refreshOne(viewer);
    return this.board(viewer, metric, await this.repo.friendsBoard(viewer));
  }

  async clubBoard(viewer: string, clubId: string, metric: BoardMetric): Promise<Board> {
    await this.requireMember(viewer);
    if (!(await this.repo.isMember(clubId, viewer))) throw new AppError('NOT_FOUND', 'No such club.');
    await this.refreshOne(viewer);
    return this.board(viewer, metric, await this.repo.clubBoard(viewer, clubId));
  }

  /** The top 100 who chose to be on it (worldwide or one country), and the viewer's own place. */
  async worldBoard(viewer: string, metric: BoardMetric, country: string | null): Promise<Board> {
    await this.requireMember(viewer);
    await this.refreshOne(viewer);
    const w = await this.week(viewer);
    const r = await this.repo.worldBoard(viewer, metric, country, WORLD_BOARD_ROWS);
    const rows = rankRows(r.rows, metric, viewer);
    const me = r.me === null ? null : { ...rowOf({ ...r.me, rank: r.me.rank }, viewer) };
    // Beta 6.2 (C12): last week among those who chose the world board and counted something.
    const weeks = [addDays(w.from, -7), addDays(w.from, -14)];
    const past = (await this.repo.worldHistory(country, weeks)).map((h) => ({ week: h.weekFrom, row: statOf(h, h) }));
    const at = (week: string) => past.filter((p) => p.week === week && counted(metric, p.row)).map((p) => p.row);
    let lastWeek = this.lastWeek(viewer, metric, weeks, at(weeks[0]!), at(weeks[1]!));
    if (lastWeek !== null) {
      // Someone who blocked the viewer, or was blocked, is left off the podium (the places stay true).
      const shown = [];
      for (const p of lastWeek.podium) if (p.me || !(await this.repo.blockedEitherWay(viewer, p.userId))) shown.push(p);
      lastWeek = shown.length === 0 ? null : { ...lastWeek, podium: shown };
    }
    return { metric, weekFrom: w.from, weekTo: w.to, rows, me, total: r.total, lastWeek };
  }

  /* --------------------------------------------------------- week counts -- */

  /**
   * This person's counts for their week, from their synced records. Beta 6.2:
   * with active days and the sessions planned up to today; when their week has
   * rolled over, the finished week is recounted and kept first (C12).
   */
  async refreshOne(userId: string): Promise<void> {
    const tz = await this.repo.timezoneOf(userId);
    const today = localDateOf(this.now(), tz);
    const from = addDays(today, 1 - isoWeekday(today));
    const prev = await this.repo.stats(userId);
    if (prev !== null && prev.weekFrom < from) {
      const end = addDays(prev.weekFrom, 6);
      const [c, planned] = await Promise.all([
        this.repo.weekCounts(userId, tz, prev.weekFrom, end, COUNTED_SESSION, COUNTED_RUN),
        this.plannedOf(userId, prev.weekFrom, end),
      ]);
      await this.repo.saveHistory(userId, { weekFrom: prev.weekFrom, ...c, streak: prev.streak, planned }, HISTORY_WEEKS_KEPT);
    }
    const [c, planned, streak] = await Promise.all([
      this.repo.weekCounts(userId, tz, from, today, COUNTED_SESSION, COUNTED_RUN),
      this.plannedOf(userId, from, today),
      this.streakOf(userId),
    ]);
    await this.repo.saveStats(userId, from, c.sessions, c.runM, streak, c.activeDays, planned);
  }

  /** Beta 6.2 (A2): recount someone after they sync a session or a run, when they are in Community. */
  async refreshIfMember(userId: string): Promise<void> {
    if ((await this.repo.profile(userId)) !== null) await this.refreshOne(userId);
  }

  /** Every member, one at a time (the timer); a failure skips that person. */
  async refreshAll(): Promise<number> {
    let n = 0;
    for (const id of await this.repo.memberIds()) {
      try {
        await this.refreshOne(id);
        n++;
      } catch {
        // The next round tries again.
      }
    }
    return n;
  }

  /* -------------------------------------------------------------- reports -- */

  async report(viewer: string, body: ReportRequest): Promise<void> {
    await this.requireMember(viewer);
    if (body.userId !== undefined && (body.userId === viewer || (await this.repo.profile(body.userId)) === null)) {
      throw new AppError('NOT_FOUND', 'No such member.');
    }
    if (body.clubId !== undefined && (await this.repo.club(body.clubId)) === null) throw new AppError('NOT_FOUND', 'No such club.');
    await this.repo.report(viewer, { ...(body.userId !== undefined ? { userId: body.userId } : {}), ...(body.clubId !== undefined ? { clubId: body.clubId } : {}) }, body.reason, body.note ?? null);
  }

  /* ---------------------------------------------------------------- admin -- */

  async adminReports(status: 'open' | 'closed') {
    const rows = await this.repo.reports(status);
    return {
      items: rows.map((r) => ({
        id: r.id,
        reason: r.reason as ReportRequest['reason'],
        note: r.note,
        status: r.status as 'open' | 'closed',
        createdAt: r.createdAt.toISOString(),
        reporterHandle: r.reporterHandle,
        target: { userId: r.targetUserId, handle: r.targetHandle, hidden: r.targetHidden, clubId: r.clubId, clubName: r.clubName },
      })),
    };
  }

  async closeReport(actor: string | null, id: string): Promise<void> {
    if (!(await this.repo.closeReport(id, actor))) throw new AppError('NOT_FOUND', 'No such open report.');
    await this.repo.audit({ actorUserId: actor, action: 'community.report.close', entity: 'community_report', entityId: id });
  }

  async adminMembers(q: string | undefined) {
    const r = await this.repo.members(q);
    return {
      total: r.total,
      items: r.items.map((p) => ({ userId: p.userId, handle: p.handle, country: p.country, onWorld: p.onWorld, hidden: p.hidden, joinedAt: p.createdAt.toISOString() })),
    };
  }

  /** Hide from every board and search, or give an unsuitable handle a new one (audited). */
  async adminUpdateMember(actor: string | null, userId: string, body: { hidden?: boolean | undefined; handle?: string | undefined }): Promise<void> {
    const p = await this.repo.profile(userId);
    if (p === null) throw new AppError('NOT_FOUND', 'No such member.');
    if (body.handle !== undefined) {
      const owner = await this.repo.handleOwner(body.handle);
      if (owner !== null && owner !== userId) throw handleRefused('taken');
    }
    await this.repo.updateProfile(userId, body);
    await this.repo.audit({ actorUserId: actor, action: 'community.member.update', entity: 'community_profile', entityId: userId, metadata: { from: p.handle, ...body } });
  }

  async adminClubs() {
    return { items: (await this.repo.allClubs()).map((c) => ({ id: c.id, name: c.name, ownerHandle: c.ownerHandle, members: c.members, createdAt: c.createdAt.toISOString() })) };
  }

  async adminDeleteClub(actor: string | null, clubId: string): Promise<void> {
    const c = await this.repo.club(clubId);
    if (c === null || !(await this.repo.deleteClub(clubId))) throw new AppError('NOT_FOUND', 'No such club.');
    await this.repo.audit({ actorUserId: actor, action: 'community.club.delete', entity: 'club', entityId: clubId, metadata: { name: c.name } });
  }
}
