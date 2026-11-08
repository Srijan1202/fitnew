/**
 * Community (beta 5.8, ADR-057): joining and leaving (the `community`
 * consent), friends, blocks, clubs, the boards and reports, and the week's
 * counts behind the boards. Nobody is seen until they join; a hidden or
 * blocking person is never seen; a board holds counts only.
 */
import { randomInt } from 'node:crypto';

import {
  CLUB_CODE_ALPHABET,
  COUNTED_RUN,
  COUNTED_SESSION,
  CURRENT_POLICY_VERSION,
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
  type ReportRequest,
  type UpdateCommunityRequest,
} from '@fitos/contracts';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';
import { isoWeekday } from '@fitos/core/progress/streak';

import { AppError } from '../../lib/errors.js';
import type { PushSender } from '../../lib/push.js';
import type { CommunityRepository, PersonRow, StatRow } from './repository.js';

/** The person's current streak (the progress service's own count). */
export type StreakOf = (userId: string) => Promise<number>;

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

/** Best first by the metric, then the other count, the streak and the handle. */
export function rankRows(rows: readonly StatRow[], metric: BoardMetric, viewer: string): BoardRow[] {
  const key = (r: StatRow): number[] => (metric === 'sessions' ? [r.sessions, r.runM, r.streak] : [r.runM, r.sessions, r.streak]);
  const sorted = [...rows].sort((a, b) => {
    const ka = key(a);
    const kb = key(b);
    for (let i = 0; i < ka.length; i++) if (ka[i] !== kb[i]) return kb[i]! - ka[i]!;
    return a.handle.localeCompare(b.handle);
  });
  // Equal counts share a rank (1, 2, 2, 4).
  const out: BoardRow[] = [];
  sorted.forEach((r, i) => {
    const prev = sorted[i - 1];
    const tied = prev !== undefined && key(prev).every((v, j) => v === key(r)[j]);
    const rank = tied ? out[i - 1]!.rank : i + 1;
    out.push({ rank, ...personOf(r), sessions: r.sessions, runM: r.runM, streak: r.streak, me: r.userId === viewer });
  });
  return out;
}

export class CommunityService {
  constructor(
    private readonly repo: CommunityRepository,
    private readonly streakOf: StreakOf,
    private readonly push: PushSender,
    private readonly now: () => Date = () => new Date(),
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
    await this.tell(requester, 'Friend request accepted', `You and @${me.handle} are friends on FITOS.`, { type: 'community', screen: 'friends' });
    return { status: 'friends' };
  }

  /** Decline, cancel or unfriend: the same act. */
  async unfriend(viewer: string, other: string): Promise<void> {
    await this.requireMember(viewer);
    await this.repo.unfriend(viewer, other);
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

  /* --------------------------------------------------------------- boards -- */

  private async week(viewer: string): Promise<{ from: string; to: string }> {
    const tz = await this.repo.timezoneOf(viewer);
    const today = localDateOf(this.now(), tz);
    const from = addDays(today, 1 - isoWeekday(today));
    return { from, to: addDays(from, 6) };
  }

  private async board(viewer: string, metric: BoardMetric, rows: StatRow[]): Promise<Board> {
    const w = await this.week(viewer);
    return { metric, weekFrom: w.from, weekTo: w.to, rows: rankRows(rows, metric, viewer), me: null, total: rows.length };
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
    const me = r.me === null ? null : { ...rankRows([r.me], metric, viewer)[0]!, rank: r.me.rank };
    return { metric, weekFrom: w.from, weekTo: w.to, rows, me, total: r.total };
  }

  /* --------------------------------------------------------- week counts -- */

  /** This person's counts for their week, from their synced records. */
  async refreshOne(userId: string): Promise<void> {
    const tz = await this.repo.timezoneOf(userId);
    const today = localDateOf(this.now(), tz);
    const from = addDays(today, 1 - isoWeekday(today));
    const [sessions, runM, streak] = await Promise.all([
      this.repo.countedSessions(userId, tz, from, COUNTED_SESSION.minSets, COUNTED_SESSION.minSeconds),
      this.repo.countedRunM(userId, tz, from, COUNTED_RUN.minM, COUNTED_RUN.fastestSecPerKm, COUNTED_RUN.slowestSecPerKm),
      this.streakOf(userId),
    ]);
    await this.repo.saveStats(userId, from, sessions, runM, streak);
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
