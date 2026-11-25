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
  FEED_KINDS,
  FEED_PAGE,
  FRIEND_DECLINE_COOLDOWN_DAYS,
  SUGGESTIONS_SHOWN,
  MAX_CLUB_MEMBERS,
  MAX_CO_OWNERS,
  MAX_CLUBS_JOINED,
  MAX_CLUBS_OWNED,
  MAX_FRIENDS,
  WORLD_BOARD_ROWS,
  handleProblem,
  type Board,
  type BoardMetric,
  type BoardPeriod,
  type BoardRow,
  type Club,
  type ClubChallenge,
  type ClubChallengeView,
  type ClubLeague,
  type ClubNumbers,
  type LeagueRow,
  type ChallengeClubRequest,
  type ClubMatch,
  type SetChallengeRequest,
  type CommunityMe,
  type CommunityPerson,
  type CommunityProfile,
  type Feed,
  type FeedKind,
  type FeedPost,
  type Suggestion,
  type FriendsResponse,
  type JoinCommunityRequest,
  type LastWeek,
  type PersonProfile,
  type ReportRequest,
  type WeekCounts,
  type UpdateCommunityRequest,
} from '@fitos/contracts';
import {
  CHALLENGE_HISTORY_SHOWN,
  CHALLENGES_KEPT_MONTHS,
  challengeReachedLine,
  challengeTitle,
  daysLeft,
  inTargetUnit,
  isReached,
  monthOf,
  monthOverEverywhere,
  monthRange,
  suggestTarget,
  type ChallengeMetric,
} from '@fitos/core/community/challenge';
import {
  LEAGUE_METRIC,
  LEAGUE_MIN_MEMBERS,
  LEAGUE_TABLE_SHOWN,
  POINTS,
  inSeason,
  isPairingDay,
  leagueOrder,
  metSet,
  pairClubs,
  seasonEnd,
  seasonEndLine,
  type LeagueClub,
} from '@fitos/core/community/league';
import {
  MATCH_RESULT_SHOWN_DAYS,
  matchDaysLeft,
  matchResult,
  matchResultLine,
  matchWeekOver,
  matchWeekStarted,
  nextWeekFrom,
  perMember,
} from '@fitos/core/community/match';
import { boardKey, keptPlanPct, placesMoved, rankBy, type BoardMetricKey } from '@fitos/core/community/board';
import {
  FEED_DAYS,
  FEED_ON_FROM_POLICY,
  NUDGE_QUIET_DAYS,
  POST_CATCH_UP_DAYS,
  POSTS_KEPT_DAYS,
  kudosLine,
  kudosPushDue,
  nudgeState,
  periodFrom,
  postFrom,
  streakPostDue,
  type NudgeState,
} from '@fitos/core/community/feed';
import { addDays, localDateOf, localHourOf } from '@fitos/core/nutrition/log';
import { isoWeekday } from '@fitos/core/progress/streak';

import { uniqueViolationOf } from '../../db/errors.js';
import { AppError } from '../../lib/errors.js';
import type { PushSender } from '../../lib/push.js';
import type { ChallengeRow, CommunityRepository, EntryRow, MatchRow, PersonRow, PostRow, StatRow, WeekRow } from './repository.js';

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

/** Beta 6.3: nudges show in the feed for as long as a friend stays quiet. */
const NUDGES_SHOWN_DAYS = NUDGE_QUIET_DAYS;
const CHEERERS_SHOWN = 10;

/** Beta 6.5 (K0): every kind shared, each from `at`. */
const allKindsFrom = (at: Date): { feed: string[]; feedSince: Record<string, string> } => ({
  feed: [...FEED_KINDS],
  feedSince: Object.fromEntries(FEED_KINDS.map((k) => [k, at.toISOString()])),
});

/** A challenge's raw count from a member's month (metres for distance). */
const partOf = (metric: string, c: { sessions: number; runM: number; activeDays: number }): number =>
  metric === 'distance' ? c.runM : metric === 'active-days' ? c.activeDays : c.sessions;

const postOf = (p: PostRow, viewer: string, cheeredBy: CommunityPerson[]): FeedPost => ({
  id: p.id,
  person: personOf(p),
  kind: p.kind as FeedPost['kind'],
  title: p.title,
  value: p.value,
  at: p.at.toISOString(),
  kudos: p.kudos,
  cheered: p.cheered,
  mine: p.userId === viewer,
  cheeredBy,
});

export class CommunityService {
  constructor(
    private readonly repo: CommunityRepository,
    private readonly streakOf: StreakOf,
    private readonly push: PushSender,
    private readonly now: () => Date = () => new Date(),
    private readonly plannedOf: PlannedOf = async () => null,
  ) {}

  /* -------------------------------------------------------------- joining -- */

  private profileOf(p: {
    handle: string;
    avatarId: string | null;
    country: string | null;
    onWorld: boolean;
    createdAt: Date;
    feed: string[];
    suggest: boolean;
    notify: boolean;
  }): CommunityProfile {
    return {
      handle: p.handle,
      avatarId: avatar(p.avatarId),
      country: p.country,
      onWorld: p.onWorld,
      joinedAt: p.createdAt.toISOString(),
      feed: p.feed as FeedKind[],
      suggest: p.suggest,
      notify: p.notify,
    };
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
      // Beta 6.5 (K0): every kind shared from joining; any can be turned off.
      await tx.updateProfile(userId, { ...allKindsFrom(this.now()), feedDefaulted: true });
      await tx.recordConsent(userId, true, CURRENT_POLICY_VERSION, ipHash);
      return p;
    });
    if (created === null) throw handleRefused('taken');
    await this.refreshOne(userId);
    return this.me(userId);
  }

  async update(userId: string, body: UpdateCommunityRequest): Promise<CommunityMe> {
    const p = await this.requireMember(userId);
    if (body.handle !== undefined) await this.checkHandle(body.handle, userId);
    // Beta 6.3 (C1): a kind switched on posts only what happens from now; one switched off loses its posts.
    let feedSince: Record<string, string> | undefined;
    if (body.feed !== undefined) {
      feedSince = { ...p.feedSince };
      for (const k of body.feed) if (!p.feed.includes(k)) feedSince[k] = this.now().toISOString();
    }
    try {
      await this.repo.updateProfile(userId, { ...body, feedSince });
    } catch (e) {
      if (uniqueViolationOf(e) !== null) throw handleRefused('taken');
      throw e;
    }
    if (body.feed !== undefined) await this.repo.prunePosts(userId, body.feed);
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

  /** Beta 6.3: a kudos summary or a nudge, only when the person allows Community notifications. */
  private async tellIfAllowed(p: { userId: string; notify: boolean }, title: string, body: string): Promise<boolean> {
    if (!p.notify) return false;
    await this.tell(p.userId, title, body, { type: 'community', screen: 'feed' });
    return true;
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
      nudge: friend ? await this.nudgeStateOf(viewer, userId) : null,
    };
  }

  /* ----------------------------------------------- beta 6.3 (C3): nudges -- */

  private async nudgeStateOf(viewer: string, friend: string): Promise<NudgeState> {
    const tz = await this.repo.timezoneOf(friend);
    const today = localDateOf(this.now(), tz);
    const [c, last] = await Promise.all([
      this.repo.periodCounts(friend, tz, addDays(today, -NUDGE_QUIET_DAYS), today, COUNTED_SESSION, COUNTED_RUN),
      this.repo.lastNudge(viewer, friend),
    ]);
    return nudgeState(c.lastActive, today, last, this.now());
  }

  /**
   * A fixed message to a friend who has counted nothing for 3 days, once a
   * week per friend; they get at most one nudge notification a day.
   */
  async nudge(viewer: string, friendId: string): Promise<void> {
    const me = await this.requireMember(viewer);
    const f = friendId === viewer ? null : await this.repo.friendship(viewer, friendId);
    if (f?.status !== 'accepted' || (await this.repo.visible(viewer, friendId)) === null) throw new AppError('NOT_FOUND', 'No such friend.');
    const state = await this.nudgeStateOf(viewer, friendId);
    if (state === 'active') throw new AppError('CONFLICT', 'They trained in the last 3 days.', [{ path: 'nudge', issue: 'active' }]);
    if (state === 'sent') throw new AppError('CONFLICT', 'You nudged them this week.', [{ path: 'nudge', issue: 'sent' }]);
    await this.repo.nudge(viewer, friendId, this.now());
    const friend = (await this.repo.profile(friendId))!;
    const today = localDateOf(this.now(), await this.repo.timezoneOf(friendId));
    if (friend.nudgePushedOn === today) return;
    if (await this.tellIfAllowed(friend, 'A nudge from a friend', `@${me.handle} nudged you: time to move. A short session counts.`)) {
      await this.repo.updateProfile(friendId, { nudgePushedOn: today });
    }
  }

  /* -------------------------------------------- beta 6.3 (C1, C2): feed -- */

  /** Your posts and friends', newest first, 20 a page, from the last 14 days; nudges on the first page. */
  async feed(viewer: string, before: string | undefined): Promise<Feed> {
    await this.requireMember(viewer);
    const now = this.now().getTime();
    const rows = await this.repo.feed(viewer, new Date(now - FEED_DAYS * 86_400_000), before === undefined ? null : new Date(before), FEED_PAGE + 1);
    const page = rows.slice(0, FEED_PAGE);
    const by = await this.cheerersOf(viewer, page);
    const nudges = before === undefined ? await this.repo.nudgesTo(viewer, new Date(now - NUDGES_SHOWN_DAYS * 86_400_000)) : [];
    return {
      items: page.map((p) => postOf(p, viewer, by.get(p.id) ?? [])),
      next: rows.length > FEED_PAGE ? page.at(-1)!.at.toISOString() : null,
      nudges: nudges.map((n) => ({ person: personOf(n), at: n.at.toISOString() })),
    };
  }

  /**
   * Beta 6.5 (K1): a club's feed, for its members: what each member shares,
   * from after they joined and agreed to the 2026-11-20 policy; 20 a page,
   * the last 14 days. Your own posts' cheerers are listed, as in the feed.
   */
  async clubFeed(viewer: string, clubId: string, before: string | undefined): Promise<Feed> {
    await this.requireMember(viewer);
    if (!(await this.repo.isMember(clubId, viewer))) throw new AppError('NOT_FOUND', 'No such club.');
    const now = this.now().getTime();
    const rows = await this.repo.clubFeed(viewer, clubId, new Date(now - FEED_DAYS * 86_400_000), before === undefined ? null : new Date(before), FEED_PAGE + 1);
    const page = rows.slice(0, FEED_PAGE);
    const by = await this.cheerersOf(viewer, page);
    return {
      items: page.map((p) => postOf(p, viewer, by.get(p.id) ?? [])),
      next: rows.length > FEED_PAGE ? page.at(-1)!.at.toISOString() : null,
      nudges: [],
    };
  }

  /** Who cheered the viewer's own posts on this page (the first 10 each). */
  private async cheerersOf(viewer: string, page: readonly PostRow[]): Promise<Map<string, CommunityPerson[]>> {
    const mine = page.filter((p) => p.userId === viewer && p.kudos > 0).map((p) => p.id);
    const by = new Map<string, CommunityPerson[]>();
    for (const c of await this.repo.cheerers(viewer, mine)) {
      const list = by.get(c.postId) ?? [];
      if (list.length < CHEERERS_SHOWN) list.push(personOf(c));
      by.set(c.postId, list);
    }
    return by;
  }

  /** Cheer a friend's or a club-mate's post (once); 404 for your own or one you cannot see. */
  async cheer(viewer: string, postId: string, on: boolean): Promise<{ kudos: number; cheered: boolean }> {
    await this.requireMember(viewer);
    if ((await this.repo.cheerablePost(viewer, postId)) === null) throw new AppError('NOT_FOUND', 'No such post.');
    if (on) await this.repo.cheer(postId, viewer);
    else await this.repo.uncheer(postId, viewer);
    return this.repo.kudosOf(postId, viewer);
  }

  /**
   * Owner Q2: one evening summary a day (19:00–23:00 local) of the kudos not
   * yet told; someone who switched notifications off is not told, and their
   * kudos are marked told. Returns how many were sent.
   */
  async kudosRound(): Promise<number> {
    let sent = 0;
    for (const w of await this.repo.kudosWaiting()) {
      try {
        if (!w.notify) {
          await this.repo.markKudosNotified(w.userId);
          continue;
        }
        const today = localDateOf(this.now(), w.tz);
        if (!kudosPushDue(localHourOf(this.now(), w.tz), today, w.pushedOn)) continue;
        const handles = await this.repo.waitingCheerers(w.userId);
        await this.repo.markKudosNotified(w.userId);
        if (handles.length === 0) continue;
        await this.tell(w.userId, 'Kudos', kudosLine(handles), { type: 'community', screen: 'feed' });
        await this.repo.updateProfile(w.userId, { kudosPushedOn: today });
        sent++;
      } catch {
        // The next round tries again.
      }
    }
    return sent;
  }

  /**
   * Posts for what this person shares (owner Q1): counted sessions and runs,
   * records and streak milestones since the kind was switched on (at most 2
   * days back, for a late sync); posts that should no longer be go first.
   */
  private async sweepPosts(
    userId: string,
    p: { feed: string[]; feedSince: Record<string, string> },
    tz: string,
    today: string,
    streak: number,
  ): Promise<void> {
    await this.repo.prunePosts(userId, p.feed);
    if (p.feed.length === 0) return;
    const window = this.now().getTime() - POST_CATCH_UP_DAYS * 86_400_000;
    const sinceOf = (k: string): Date => {
      const s = p.feedSince[k];
      return new Date(Math.max(window, s === undefined ? window : Date.parse(s)));
    };
    const { minM, fastestSecPerKm: fast, slowestSecPerKm: slow } = COUNTED_RUN;
    if (p.feed.includes('session')) {
      await this.repo.savePosts(userId, 'session', await this.repo.sessionEvents(userId, sinceOf('session'), COUNTED_SESSION.minSets, COUNTED_SESSION.minSeconds));
    }
    if (p.feed.includes('run')) await this.repo.savePosts(userId, 'run', await this.repo.runEvents(userId, sinceOf('run'), minM, fast, slow));
    if (p.feed.includes('record')) {
      await this.repo.savePosts(userId, 'lift-record', await this.repo.liftRecordEvents(userId, sinceOf('record')));
      await this.repo.savePosts(userId, 'run-record', await this.repo.runRecordEvents(userId, sinceOf('record'), minM, fast, slow));
    }
    if (p.feed.includes('streak')) {
      const due = streakPostDue(streak, today, postFrom(today, localDateOf(sinceOf('streak'), tz)));
      if (due !== null) await this.repo.savePosts(userId, 'streak', [{ ref: due.ref, title: null, value: due.milestone, at: this.now() }]);
    }
  }

  /* --------------------------------------- beta 6.3 (C16): suggestions -- */

  async suggestions(viewer: string): Promise<Suggestion[]> {
    await this.requireMember(viewer);
    return (await this.repo.suggestions(viewer, SUGGESTIONS_SHOWN)).map((s) => ({ person: personOf(s), mutualFriends: s.mutual, club: s.club }));
  }

  /** Never suggest this person again. */
  async dismissSuggestion(viewer: string, userId: string): Promise<void> {
    await this.requireMember(viewer);
    if (userId === viewer || (await this.repo.visible(viewer, userId)) === null) throw new AppError('NOT_FOUND', 'No such member.');
    await this.repo.dismissSuggestion(viewer, userId);
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

  private clubOf(
    c: { id: string; name: string; code: string; ownerId: string; members: number; createdAt: Date; coOwners: string[]; seasonWinner: boolean },
    viewer: string,
  ): Club {
    return {
      id: c.id,
      name: c.name,
      code: c.code,
      members: c.members,
      mine: c.ownerId === viewer,
      createdAt: c.createdAt.toISOString(),
      ownerId: c.ownerId,
      coOwners: c.coOwners,
      role: c.ownerId === viewer ? 'owner' : c.coOwners.includes(viewer) ? 'co-owner' : 'member',
      seasonWinner: c.seasonWinner,
    };
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

  /** Leaving a club you made passes it to a co-owner, else its longest member (or deletes it when empty). */
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

  /**
   * Beta 6.6 (L2, owner Q5): the club when the viewer runs it, as its owner
   * or a co-owner: 404 when they are not in it, 403 when they only belong.
   */
  private async requireRunner(viewer: string, clubId: string) {
    await this.requireMember(viewer);
    const c = await this.repo.club(clubId);
    if (c === null || !(await this.repo.isMember(clubId, viewer))) throw new AppError('NOT_FOUND', 'No such club.');
    if (c.ownerId !== viewer && !c.coOwners.includes(viewer)) {
      throw new AppError('FORBIDDEN', "Only the club's owner or a co-owner can do that.", [{ path: 'clubs', issue: 'not-owner' }]);
    }
    return c;
  }

  /**
   * Beta 6.6 (L2, owner Q5): the owner names a member co-owner (up to 2) or
   * drops one; the person is told either way.
   */
  async setCoOwner(viewer: string, clubId: string, userId: string, on: boolean): Promise<Club> {
    const c = await this.requireOwner(viewer, clubId);
    if (userId === viewer || !(await this.repo.isMember(clubId, userId))) throw new AppError('NOT_FOUND', 'No such member in this club.');
    const already = c.coOwners.includes(userId);
    if (on && !already) {
      if (c.coOwners.length >= MAX_CO_OWNERS) {
        throw new AppError('CONFLICT', `A club has ${MAX_CO_OWNERS} co-owners at most.`, [{ path: 'coOwners', issue: 'limit' }]);
      }
      await this.repo.setRole(clubId, userId, 'co-owner');
      await this.tell(userId, 'You help run a club', `You are now a co-owner of ${c.name} on FITOS.`, { type: 'community', screen: 'clubs' });
    } else if (!on && already) {
      await this.repo.setRole(clubId, userId, 'member');
      await this.tell(userId, 'A club change', `You are no longer a co-owner of ${c.name}.`, { type: 'community', screen: 'clubs' });
    }
    return this.clubOf((await this.repo.club(clubId))!, viewer);
  }

  async renameClub(viewer: string, clubId: string, name: string): Promise<Club> {
    await this.requireRunner(viewer, clubId);
    await this.repo.renameClub(clubId, name);
    return this.clubOf((await this.repo.club(clubId))!, viewer);
  }

  /** A new code: the old one stops working at once. */
  async newClubCode(viewer: string, clubId: string): Promise<Club> {
    await this.requireRunner(viewer, clubId);
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
    const c = await this.requireRunner(viewer, clubId);
    if (userId === viewer) throw new AppError('VALIDATION_FAILED', 'Pass the club to someone, or leave it.');
    // Beta 6.6 (L2): a co-owner removes members, never the owner or another co-owner.
    if (c.ownerId !== viewer && (userId === c.ownerId || c.coOwners.includes(userId))) {
      throw new AppError('FORBIDDEN', 'Only the owner can do that.', [{ path: 'clubs', issue: 'co-owner' }]);
    }
    if (!(await this.repo.isMember(clubId, userId))) throw new AppError('NOT_FOUND', 'No such member in this club.');
    await this.repo.inTransaction((tx) => tx.removeFromClub(clubId, userId));
  }

  async removedFrom(viewer: string, clubId: string): Promise<CommunityPerson[]> {
    await this.requireRunner(viewer, clubId);
    return (await this.repo.removedFrom(clubId)).map(personOf);
  }

  async letBack(viewer: string, clubId: string, userId: string): Promise<void> {
    await this.requireRunner(viewer, clubId);
    if (!(await this.repo.letBack(clubId, userId))) throw new AppError('NOT_FOUND', 'They were not removed from this club.');
  }

  /* --------------------------------------- beta 6.5 (K2): club challenge -- */

  private challengeOf(c: ChallengeRow, mine: number | null, today: string): ClubChallenge {
    const metric = c.metric as ChallengeMetric;
    return {
      id: c.id,
      metric,
      target: c.target,
      month: c.month,
      title: challengeTitle(metric, c.target, c.month),
      total: inTargetUnit(metric, c.total),
      mine: mine === null ? null : inTargetUnit(metric, mine),
      reachedAt: c.reachedAt?.toISOString() ?? null,
      closedAt: c.closedAt?.toISOString() ?? null,
      endedEarly: c.endedEarly,
      daysLeft: c.closedAt === null ? daysLeft(c.month, today) : 0,
      started: today >= monthRange(c.month).from,
    };
  }

  /** The viewer's month, and the one after. */
  private async monthsOf(userId: string): Promise<{ today: string; thisMonth: string; nextMonth: string }> {
    const today = localDateOf(this.now(), await this.repo.timezoneOf(userId));
    const thisMonth = monthOf(today);
    return { today, thisMonth, nextMonth: monthOf(addDays(monthRange(thisMonth).to, 1)) };
  }

  /** The club's challenge now, its last three finished, and for the owner the suggested targets. */
  async clubChallenge(viewer: string, clubId: string): Promise<ClubChallengeView> {
    await this.requireMember(viewer);
    const club = await this.repo.club(clubId);
    if (club === null || !(await this.repo.isMember(clubId, viewer))) throw new AppError('NOT_FOUND', 'No such club.');
    await this.refreshOne(viewer);
    const { today, thisMonth } = await this.monthsOf(viewer);
    const open = await this.repo.openChallenge(clubId);
    const history = await this.repo.finishedChallenges(clubId, CHALLENGE_HISTORY_SHOWN);
    let suggested: ClubChallengeView['suggested'] = null;
    if (club.ownerId === viewer || club.coOwners.includes(viewer)) {
      const w = await this.week(viewer);
      const last = await this.repo.clubWeeksTotal(clubId, [1, 2, 3, 4].map((i) => addDays(w.from, -7 * i)));
      const month = open?.month ?? thisMonth;
      const of = (m: ChallengeMetric) => suggestTarget(m, partOf(m, last), month);
      suggested = { sessions: of('sessions'), distance: of('distance'), 'active-days': of('active-days') };
    }
    return {
      current: open === null ? null : this.challengeOf(open, await this.repo.challengePart(open.id, viewer), today),
      history: history.map((c) => this.challengeOf(c, null, today)),
      suggested,
    };
  }

  /**
   * The owner sets the club's one challenge, for their month or the next;
   * every member's part is counted at once.
   */
  async setChallenge(viewer: string, clubId: string, body: SetChallengeRequest): Promise<ClubChallengeView> {
    await this.requireRunner(viewer, clubId);
    const { thisMonth, nextMonth } = await this.monthsOf(viewer);
    const month = body.month ?? thisMonth;
    if (month !== thisMonth && month !== nextMonth) {
      throw new AppError('VALIDATION_FAILED', 'Set a challenge for this month or the next.', [{ path: 'month', issue: 'out-of-range' }]);
    }
    const made = await this.repo.createChallenge(clubId, viewer, body.metric, body.target, month);
    if (made === null) throw new AppError('CONFLICT', 'This club has a challenge already: change it or end it first.', [{ path: 'challenge', issue: 'open' }]);
    for (const userId of await this.repo.clubMemberIds(clubId)) {
      try {
        const tz = await this.repo.timezoneOf(userId);
        await this.countParts(userId, tz, localDateOf(this.now(), tz));
      } catch {
        // The hourly round counts them.
      }
    }
    return this.clubChallenge(viewer, clubId);
  }

  /** A new target, until the challenge is reached. */
  async changeChallenge(viewer: string, clubId: string, target: number): Promise<ClubChallengeView> {
    await this.requireRunner(viewer, clubId);
    const open = await this.repo.openChallenge(clubId);
    if (open === null) throw new AppError('NOT_FOUND', 'This club has no challenge now.');
    if (open.reachedAt !== null) throw new AppError('CONFLICT', 'It is reached: end it and set a new one.', [{ path: 'challenge', issue: 'reached' }]);
    await this.repo.setChallengeTarget(open.id, target);
    return this.clubChallenge(viewer, clubId);
  }

  /** End it before the month is over; it stays in the club's history. */
  async endChallenge(viewer: string, clubId: string): Promise<void> {
    await this.requireRunner(viewer, clubId);
    const open = await this.repo.openChallenge(clubId);
    if (open === null) throw new AppError('NOT_FOUND', 'This club has no challenge now.');
    await this.repo.closeChallenge(open.id, this.now(), true);
  }

  /* ------------------------------------------ beta 6.5 (K3): club vs club -- */

  private async matchOf(m: MatchRow, clubId: string, today: string): Promise<ClubMatch> {
    const metric = m.metric as ChallengeMetric;
    const home = m.homeClubId === clubId;
    let homeScore: number | null = null;
    let awayScore: number | null = null;
    if (m.status === 'finished') {
      homeScore = perMember(metric, m.homeScore ?? 0, m.homeMembers ?? 0);
      awayScore = perMember(metric, m.awayScore ?? 0, m.awayMembers ?? 0);
    } else if (m.startedAt !== null) {
      const totals = await this.repo.matchTotals(m.id, m.metric, m.weekFrom);
      homeScore = perMember(metric, totals.get(m.homeClubId) ?? 0, m.homeMembers ?? 0);
      awayScore = perMember(metric, totals.get(m.awayClubId) ?? 0, m.awayMembers ?? 0);
    }
    const us = { clubId, name: home ? m.homeName : m.awayName, score: home ? homeScore : awayScore };
    const them = { clubId: home ? m.awayClubId : m.homeClubId, name: home ? m.awayName : m.homeName, score: home ? awayScore : homeScore };
    return {
      id: m.id,
      metric,
      weekFrom: m.weekFrom,
      weekTo: addDays(m.weekFrom, 6),
      status: m.status as ClubMatch['status'],
      challenger: home,
      us,
      them,
      members: m.startedAt === null ? null : (home ? m.homeMembers : m.awayMembers),
      daysLeft: m.status === 'finished' ? 0 : matchDaysLeft(m.weekFrom, today),
      result: m.status === 'finished' ? matchResult(us.score!, them.score!) : null,
    };
  }

  /** A club's matches, for its members: waiting, on, and finished in the last week. */
  async clubMatches(viewer: string, clubId: string): Promise<ClubMatch[]> {
    await this.requireMember(viewer);
    if (!(await this.repo.isMember(clubId, viewer))) throw new AppError('NOT_FOUND', 'No such club.');
    await this.refreshOne(viewer);
    const today = localDateOf(this.now(), await this.repo.timezoneOf(viewer));
    const rows = await this.repo.matchesOf(clubId, new Date(this.now().getTime() - MATCH_RESULT_SHOWN_DAYS * 86_400_000));
    const out: ClubMatch[] = [];
    for (const m of rows) out.push(await this.matchOf(m, clubId, today));
    return out;
  }

  /**
   * The owner challenges the club with this code to next week (their week).
   * One match a week for either club; never across a block between the owners.
   */
  async challengeClub(viewer: string, clubId: string, body: ChallengeClubRequest): Promise<ClubMatch[]> {
    const c = await this.requireRunner(viewer, clubId);
    const other = await this.repo.clubByCode(body.code);
    // A block between the owners, or between a co-owner and the other owner.
    if (other === null || (await this.repo.blockedEitherWay(c.ownerId, other.ownerId)) || (await this.repo.blockedEitherWay(viewer, other.ownerId))) {
      throw new AppError('NOT_FOUND', 'No club has that code.');
    }
    if (other.id === clubId) throw new AppError('VALIDATION_FAILED', 'Challenge another club.', [{ path: 'code', issue: 'self' }]);
    const weekFrom = nextWeekFrom(localDateOf(this.now(), await this.repo.timezoneOf(viewer)));
    if (await this.repo.clubBusy(clubId, weekFrom)) throw new AppError('CONFLICT', 'Your club has a match next week.', [{ path: 'match', issue: 'busy' }]);
    if (await this.repo.clubBusy(other.id, weekFrom)) throw new AppError('CONFLICT', 'That club has a match next week.', [{ path: 'match', issue: 'other-busy' }]);
    await this.repo.createMatch(clubId, other.id, body.metric, weekFrom);
    return this.clubMatches(viewer, clubId);
  }

  /** The challenged club's owner accepts, before the week starts. */
  async acceptMatch(viewer: string, clubId: string, matchId: string): Promise<ClubMatch[]> {
    const c = await this.requireRunner(viewer, clubId);
    const m = await this.repo.match(matchId);
    if (
      m === null ||
      m.awayClubId !== clubId ||
      m.status !== 'pending' ||
      (await this.repo.blockedEitherWay(c.ownerId, m.homeOwnerId)) ||
      (await this.repo.blockedEitherWay(viewer, m.homeOwnerId))
    ) {
      throw new AppError('NOT_FOUND', 'No such challenge.');
    }
    if (localDateOf(this.now(), await this.repo.timezoneOf(viewer)) >= m.weekFrom) {
      throw new AppError('CONFLICT', 'That week has started.', [{ path: 'match', issue: 'started' }]);
    }
    await this.repo.acceptMatch(matchId, this.now());
    return this.clubMatches(viewer, clubId);
  }

  /** Decline a challenge, take one back, or call a match off before its week starts. */
  async cancelMatch(viewer: string, clubId: string, matchId: string): Promise<void> {
    await this.requireRunner(viewer, clubId);
    const m = await this.repo.match(matchId);
    if (m === null || (m.homeClubId !== clubId && m.awayClubId !== clubId)) throw new AppError('NOT_FOUND', 'No such match.');
    if (m.startedAt !== null || m.status === 'finished') throw new AppError('CONFLICT', 'That week has started.', [{ path: 'match', issue: 'started' }]);
    if (m.leagueSeasonId !== null) throw new AppError('CONFLICT', 'A league match cannot be called off.', [{ path: 'match', issue: 'league' }]);
    await this.repo.deleteMatch(matchId);
  }

  /* ------------------------------------------ beta 6.6 (M3): club numbers -- */

  /** The club this month in totals, and its best week so far (weeks that touch the month). */
  async clubNumbers(viewer: string, clubId: string): Promise<ClubNumbers> {
    await this.requireMember(viewer);
    if (!(await this.repo.isMember(clubId, viewer))) throw new AppError('NOT_FOUND', 'No such club.');
    await this.refreshOne(viewer);
    const { thisMonth } = await this.monthsOf(viewer);
    const m = await this.repo.clubMonth(clubId);
    return {
      month: thisMonth,
      sessions: m.sessions,
      runKm: inTargetUnit('distance', m.runM),
      activeDays: m.activeDays,
      bestWeek: await this.repo.clubBestWeek(clubId, addDays(monthRange(thisMonth).from, -6)),
    };
  }

  /* ------------------------------------------------ beta 6.6 (L1): league -- */

  private ordered(entries: readonly EntryRow[]) {
    return leagueOrder(entries.map((e) => ({ ...e, scoreSum: e.scoreTenths / 10 })));
  }

  private leagueRowOf(r: EntryRow & { place: number }, clubId: string): LeagueRow {
    return { place: r.place, clubId: r.clubId, name: r.name, played: r.played, won: r.won, drawn: r.drawn, lost: r.lost, byes: r.byes, points: r.points, mine: r.clubId === clubId };
  }

  /** The club's place in the league: the top 5 and its own row (or every club with `all`). */
  async clubLeague(viewer: string, clubId: string, all = false): Promise<ClubLeague> {
    await this.requireMember(viewer);
    const c = await this.repo.club(clubId);
    if (c === null || !(await this.repo.isMember(clubId, viewer))) throw new AppError('NOT_FOUND', 'No such club.');
    const entry = await this.repo.leagueClub(clubId);
    const season = await this.repo.latestSeason();
    const rows = season === null ? [] : this.ordered(await this.repo.entriesOf(season.id)).map((r) => this.leagueRowOf(r, clubId));
    const me = rows.find((r) => r.mine) ?? null;
    const top = rows.slice(0, LEAGUE_TABLE_SHOWN);
    return {
      entered: entry !== null,
      leaving: entry?.leaving ?? false,
      canEnter: c.members >= LEAGUE_MIN_MEMBERS,
      season: season === null ? null : { startsOn: season.startsOn, endsOn: season.endsOn, finished: season.finishedAt !== null },
      me,
      table: all || me === null || top.includes(me) ? (all ? rows : top) : [...top, me],
      clubs: rows.length,
    };
  }

  /** The owner or a co-owner enters a club of 3 or more (owner Q2), or takes it back in. */
  async enterLeague(viewer: string, clubId: string): Promise<ClubLeague> {
    const c = await this.requireRunner(viewer, clubId);
    if (c.members < LEAGUE_MIN_MEMBERS) {
      throw new AppError('CONFLICT', `A club needs ${LEAGUE_MIN_MEMBERS} members to enter the league.`, [{ path: 'league', issue: 'too-small' }]);
    }
    await this.repo.enterLeague(clubId);
    return this.clubLeague(viewer, clubId);
  }

  /** Out after this week: not paired again; its season row stays. */
  async leaveLeague(viewer: string, clubId: string): Promise<ClubLeague> {
    await this.requireRunner(viewer, clubId);
    if ((await this.repo.leagueClub(clubId)) === null) throw new AppError('NOT_FOUND', 'This club is not in the league.');
    await this.repo.leaveLeague(clubId);
    return this.clubLeague(viewer, clubId);
  }

  /**
   * Beta 6.6 (L1), after the match round: a season whose last results are in
   * gets its places and the one push to each member who allows Community
   * notifications (owner Q4); seasons are kept a year. On Saturdays (UTC) the
   * entered clubs without a match are paired for the coming week, once.
   */
  async leagueRound(): Promise<void> {
    const now = this.now();
    const utcToday = now.toISOString().slice(0, 10);
    for (const s of await this.repo.seasonsToFinish(addDays(utcToday, -2))) {
      try {
        const ordered = this.ordered(await this.repo.entriesOf(s.id));
        await this.repo.finishSeason(s.id, ordered.map((r) => ({ clubId: r.clubId, place: r.place })), now);
        for (const r of ordered) {
          const line = seasonEndLine(r.name, r.place, ordered.length);
          for (const m of await this.repo.clubMembersToTell(r.clubId)) {
            if (m.notify) await this.tell(m.userId, line.title, line.body, { type: 'community', screen: 'club', clubId: r.clubId });
          }
        }
      } catch {
        // The next round tries again.
      }
    }
    const kept = new Date(now);
    kept.setUTCMonth(kept.getUTCMonth() - CHALLENGES_KEPT_MONTHS);
    await this.repo.deleteSeasonsFinishedBefore(kept);

    if (!isPairingDay(utcToday)) return;
    const weekFrom = nextWeekFrom(utcToday);
    const latest = await this.repo.latestSeason();
    const season = latest !== null && inSeason(latest.startsOn, weekFrom) ? latest : await this.repo.seasonStarting(weekFrom, seasonEnd(weekFrom));
    if (season.pairedWeek === weekFrom) return;
    await this.repo.dropLeavingClubs();
    const entries = new Map((await this.repo.entriesOf(season.id)).map((e) => [e.clubId, e]));
    const weeks = [1, 2, 3, 4].map((i) => addDays(weekFrom, -7 * i));
    const pool: LeagueClub[] = [];
    const owners = new Map<string, string>();
    for (const c of await this.repo.leagueClubList()) {
      if (c.members < LEAGUE_MIN_MEMBERS || (await this.repo.clubBusy(c.clubId, weekFrom))) continue;
      const t = await this.repo.clubWeeksTotal(c.clubId, weeks);
      pool.push({ id: c.clubId, avg: t.activeDays / c.members, byes: entries.get(c.clubId)?.byes ?? 0 });
      owners.set(c.clubId, c.ownerId);
    }
    const blocks = await this.repo.blocksAmong([...new Set(owners.values())]);
    const met = metSet((await this.repo.seasonPairs(season.id)).map((p) => [p.home, p.away] as const));
    const paired = pairClubs(pool, met, (a, b) => blocks.has(`${owners.get(a)}|${owners.get(b)}`));
    for (const [home, away] of paired.pairs) {
      await this.repo.createLeagueMatch(home, away, LEAGUE_METRIC, weekFrom, season.id, now);
      await this.repo.ensureEntry(season.id, home);
      await this.repo.ensureEntry(season.id, away);
    }
    for (const id of paired.byes) await this.repo.addBye(season.id, id, POINTS.bye);
    await this.repo.markPaired(season.id, weekFrom);
  }

  /* --------------------------------------------------------------- boards -- */

  private async week(viewer: string): Promise<{ from: string; to: string }> {
    const tz = await this.repo.timezoneOf(viewer);
    const today = localDateOf(this.now(), tz);
    const from = addDays(today, 1 - isoWeekday(today));
    return { from, to: addDays(from, 6) };
  }

  /** Beta 6.3 (C13): the viewer's period, from its first day to today. */
  private async periodOf(viewer: string, period: BoardPeriod): Promise<{ period: BoardPeriod; periodFrom: string; periodTo: string }> {
    const tz = await this.repo.timezoneOf(viewer);
    const today = localDateOf(this.now(), tz);
    const p = await this.repo.profile(viewer);
    const joinedOn = p === null ? today : localDateOf(p.createdAt, tz);
    return { period, periodFrom: periodFrom(period, today, joinedOn), periodTo: today };
  }

  private async board(viewer: string, metric: BoardMetric, rows: StatRow[], period: BoardPeriod): Promise<Board> {
    const w = await this.week(viewer);
    const ranked = rankRows(rows, metric, viewer);
    const p = await this.periodOf(viewer, period);
    if (period !== 'week') return { metric, weekFrom: w.from, weekTo: w.to, rows: ranked, me: null, total: ranked.length, lastWeek: null, ...p };
    // Beta 6.2 (C12): the same people, last week and the week before.
    const weeks = [addDays(w.from, -7), addDays(w.from, -14)];
    const people = new Map(rows.map((r) => [r.userId, r as PersonRow]));
    const past = await this.repo.history([...people.keys()], weeks);
    const at = (week: string) => past.filter((h) => h.weekFrom === week).map((h) => statOf(people.get(h.userId)!, h));
    return {
      metric,
      weekFrom: w.from,
      weekTo: w.to,
      rows: ranked,
      me: null,
      total: ranked.length,
      lastWeek: this.lastWeek(viewer, metric, weeks, at(weeks[0]!), at(weeks[1]!)),
      ...p,
    };
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

  async friendsBoard(viewer: string, metric: BoardMetric, period: BoardPeriod = 'week'): Promise<Board> {
    await this.requireMember(viewer);
    await this.refreshOne(viewer);
    return this.board(viewer, metric, await this.repo.friendsBoard(viewer, period), period);
  }

  async clubBoard(viewer: string, clubId: string, metric: BoardMetric, period: BoardPeriod = 'week'): Promise<Board> {
    await this.requireMember(viewer);
    if (!(await this.repo.isMember(clubId, viewer))) throw new AppError('NOT_FOUND', 'No such club.');
    await this.refreshOne(viewer);
    return this.board(viewer, metric, await this.repo.clubBoard(viewer, clubId, period), period);
  }

  /** The top 100 who chose to be on it (worldwide or one country), and the viewer's own place. */
  async worldBoard(viewer: string, metric: BoardMetric, country: string | null, period: BoardPeriod = 'week'): Promise<Board> {
    await this.requireMember(viewer);
    await this.refreshOne(viewer);
    const w = await this.week(viewer);
    const r = await this.repo.worldBoard(viewer, metric, country, WORLD_BOARD_ROWS, period);
    const rows = rankRows(r.rows, metric, viewer);
    const me = r.me === null ? null : { ...rowOf({ ...r.me, rank: r.me.rank }, viewer) };
    const p = await this.periodOf(viewer, period);
    if (period !== 'week') return { metric, weekFrom: w.from, weekTo: w.to, rows, me, total: r.total, lastWeek: null, ...p };
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
    return { metric, weekFrom: w.from, weekTo: w.to, rows, me, total: r.total, lastWeek, ...p };
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
    // Beta 6.3 (C13): the same for the week, the month and since joining.
    let p = await this.repo.profile(userId);
    if (p === null) return;
    // Beta 6.5 (K0, owner Q5): someone who joined earlier has every kind switched on, once, from agreeing to the 2026-11-20 policy.
    if (!p.feedDefaulted) {
      const agreed = await this.repo.agreedSince(userId, FEED_ON_FROM_POLICY);
      if (agreed !== null) {
        const on = allKindsFrom(agreed);
        await this.repo.updateProfile(userId, { ...on, feedDefaulted: true });
        p = { ...p, ...on, feedDefaulted: true };
      }
    }
    await this.repo.savePeriod(userId, 'week', { periodFrom: from, sessions: c.sessions, runM: c.runM, streak, activeDays: c.activeDays, planned });
    const joinedOn = localDateOf(p.createdAt, tz);
    for (const period of ['month', 'all'] as const) {
      const pf = periodFrom(period, today, joinedOn);
      const [pc, pp] = await Promise.all([this.repo.periodCounts(userId, tz, pf, today, COUNTED_SESSION, COUNTED_RUN), this.plannedOf(userId, pf, today)]);
      await this.repo.savePeriod(userId, period, { periodFrom: pf, sessions: pc.sessions, runM: pc.runM, streak, activeDays: pc.activeDays, planned: pp });
    }
    // Beta 6.3 (C1): their posts.
    await this.sweepPosts(userId, p, tz, today, streak);
    // Beta 6.5 (K2): their part in their clubs' challenges.
    await this.countParts(userId, tz, today);
  }

  /** Beta 6.2 (A2): recount someone after they sync a session or a run, when they are in Community. */
  async refreshIfMember(userId: string): Promise<void> {
    if ((await this.repo.profile(userId)) !== null) await this.refreshOne(userId);
  }

  /**
   * Beta 6.5 (K2): this member's part in each open challenge of their clubs,
   * from the month's first day to today (or its last day) in their own time
   * zone; nothing before the month starts. The club's count follows.
   */
  private async countParts(userId: string, tz: string, today: string): Promise<void> {
    const months = new Map<string, Promise<{ sessions: number; runM: number; activeDays: number }>>();
    for (const c of await this.repo.openChallengesOf(userId)) {
      const { from, to } = monthRange(c.month);
      if (today < from) continue;
      const end = today < to ? today : to;
      if (!months.has(c.month)) months.set(c.month, this.repo.periodCounts(userId, tz, from, end, COUNTED_SESSION, COUNTED_RUN));
      await this.repo.savePart(c.id, userId, partOf(c.metric, await months.get(c.month)!));
      await this.repo.recountChallenge(c.id);
    }
  }

  /** Every member, one at a time (the timer); a failure skips that person. */
  async refreshAll(): Promise<number> {
    // Beta 6.3: posts are kept 30 days.
    await this.repo.deleteOldPosts(new Date(this.now().getTime() - POSTS_KEPT_DAYS * 86_400_000));
    let n = 0;
    for (const id of await this.repo.memberIds()) {
      try {
        await this.refreshOne(id);
        n++;
      } catch {
        // The next round tries again.
      }
    }
    await this.challengeRound();
    await this.matchRound();
    await this.leagueRound();
    return n;
  }

  /**
   * Beta 6.5 (K3), after every member is recounted: an unanswered challenge
   * lapses when its week starts; an accepted one fixes its members then; once
   * the week is over everywhere the result is kept and each member who allows
   * Community notifications gets the one push (owner Q4), from their club's
   * side; a result stays a week.
   */
  async matchRound(): Promise<void> {
    const now = this.now();
    const utcToday = now.toISOString().slice(0, 10);
    await this.repo.lapseMatches(utcToday);
    for (const m of await this.repo.matchesToStart(utcToday)) {
      if (matchWeekStarted(m.weekFrom, utcToday)) await this.repo.startMatch(m.id, now);
    }
    for (const m of await this.repo.liveMatches()) {
      if (!matchWeekOver(m.weekFrom, utcToday)) continue;
      try {
        const totals = await this.repo.matchTotals(m.id, m.metric, m.weekFrom);
        const home = totals.get(m.homeClubId) ?? 0;
        const away = totals.get(m.awayClubId) ?? 0;
        await this.repo.finishMatch(m.id, home, away, now);
        const metric = m.metric as ChallengeMetric;
        const h = perMember(metric, home, m.homeMembers ?? 0);
        const a = perMember(metric, away, m.awayMembers ?? 0);
        // Beta 6.6 (L1): a league match's points.
        if (m.leagueSeasonId !== null) {
          for (const [clubId, us, them] of [[m.homeClubId, h, a], [m.awayClubId, a, h]] as const) {
            const r = matchResult(us, them);
            await this.repo.recordLeagueResult(m.leagueSeasonId, clubId, r, POINTS[r], Math.round(us * 10));
          }
        }
        const told = new Set<string>();
        for (const [clubId, line] of [
          [m.homeClubId, matchResultLine(m.homeName, m.awayName, metric, h, a)],
          [m.awayClubId, matchResultLine(m.awayName, m.homeName, metric, a, h)],
        ] as const) {
          for (const x of await this.repo.clubMembersToTell(clubId)) {
            if (!x.notify || told.has(x.userId)) continue;
            told.add(x.userId);
            await this.tell(x.userId, line.title, line.body, { type: 'community', screen: 'club', clubId });
          }
        }
      } catch {
        // The next round tries again.
      }
    }
    await this.repo.deleteFinishedMatches(new Date(now.getTime() - MATCH_RESULT_SHOWN_DAYS * 86_400_000));
  }

  /**
   * Beta 6.5 (K2), after every member is recounted: each open challenge's
   * count; the one push to its members when it is reached (owner Q4, only to
   * those who allow Community notifications); closing once its month is over
   * in every time zone; finished ones kept a year.
   */
  async challengeRound(): Promise<void> {
    const now = this.now();
    const utcToday = now.toISOString().slice(0, 10);
    for (const c of await this.repo.openChallenges()) {
      try {
        const total = await this.repo.recountChallenge(c.id);
        if (c.reachedAt === null && isReached(c.metric as ChallengeMetric, total, c.target) && (await this.repo.markReached(c.id, now))) {
          const line = challengeReachedLine(c.clubName, challengeTitle(c.metric as ChallengeMetric, c.target, c.month));
          for (const m of await this.repo.clubMembersToTell(c.clubId)) {
            if (m.notify) await this.tell(m.userId, line.title, line.body, { type: 'community', screen: 'club', clubId: c.clubId });
          }
        }
        if (monthOverEverywhere(c.month, utcToday)) await this.repo.closeChallenge(c.id, now, false);
      } catch {
        // The next round tries again.
      }
    }
    const kept = new Date(now);
    kept.setUTCMonth(kept.getUTCMonth() - CHALLENGES_KEPT_MONTHS);
    await this.repo.deleteChallengesClosedBefore(kept);
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
    return {
      items: (await this.repo.allClubs()).map((c) => {
        const ch = c.challenge;
        const metric = ch?.metric as ChallengeMetric;
        return {
          id: c.id,
          name: c.name,
          ownerHandle: c.ownerHandle,
          members: c.members,
          createdAt: c.createdAt.toISOString(),
          challenge:
            ch === null ? null : `${challengeTitle(metric, ch.target, ch.month)} · ${inTargetUnit(metric, ch.total)} so far${ch.reached ? ' · reached' : ''}`,
          match: c.match === null ? null : `vs ${c.match.other} · week of ${c.match.weekFrom} · ${c.match.status}`,
        };
      }),
    };
  }

  async adminDeleteClub(actor: string | null, clubId: string): Promise<void> {
    const c = await this.repo.club(clubId);
    if (c === null || !(await this.repo.deleteClub(clubId))) throw new AppError('NOT_FOUND', 'No such club.');
    await this.repo.audit({ actorUserId: actor, action: 'community.club.delete', entity: 'club', entityId: clubId, metadata: { name: c.name } });
  }
}
