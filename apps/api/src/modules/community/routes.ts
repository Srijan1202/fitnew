/**
 * Community (beta 5.8, ADR-057). Behind the admin's `community` switch.
 * For the member: /community/me (join, change, leave), people, friends,
 * blocks, clubs, the three boards and reports. For the admin (claim checked
 * before validation, every change audited): reports, members and clubs.
 */
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { z } from 'zod';
import {
  adminClubListSchema,
  adminCommunityMemberListSchema,
  adminCommunityMemberQuerySchema,
  adminCommunityReportListSchema,
  adminCommunityReportQuerySchema,
  adminUpdateMemberSchema,
  blockRequestSchema,
  boardMetricSchema,
  boardPeriodSchema,
  boardQuerySchema,
  boardSchema,
  clubListSchema,
  clubSchema,
  communityMeSchema,
  createClubSchema,
  errorEnvelopeSchema,
  feedQuerySchema,
  feedSchema,
  friendRequestResultSchema,
  friendRequestSchema,
  friendsResponseSchema,
  joinClubSchema,
  joinCommunitySchema,
  kudosResultSchema,
  passClubSchema,
  personListSchema,
  personProfileSchema,
  renameClubSchema,
  reportRequestSchema,
  searchQuerySchema,
  suggestionListSchema,
  updateCommunitySchema,
} from '@fitos/contracts';

import { plannedBetween } from '@fitos/core/community/board';

import { AppError } from '../../lib/errors.js';
import { requireAdmin } from '../../plugins/auth.js';
import { hashIp } from '../onboarding/service.js';
import { FoodLogRepository } from '../nutrition/log-repository.js';
import { ProgressRepository } from '../progress/repository.js';
import { ProgressService } from '../progress/service.js';
import { PlanRepository } from '../running/plan-repository.js';
import { CommunityRepository } from './repository.js';
import { CommunityService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

/** Friend requests a day: enough to add a gym's worth of friends, not to spam. */
export const FRIEND_REQUESTS_PER_DAY = 30;
/** Reports a day. */
export const REPORTS_PER_DAY = 10;
/** Club joins and creations a day. */
export const CLUB_ACTIONS_PER_DAY = 20;
/** Beta 6.2 (S8): handle searches a day. */
export const SEARCHES_PER_DAY = 300;
/** Beta 6.2 (C5): a club owner's changes a day. */
export const CLUB_OWNER_ACTIONS_PER_DAY = 60;
/**
 * How often the server recounts every member's week. Beta 6.2 (A2): hourly,
 * as a catch-up; a completed session or a saved run recounts that person at once.
 */
export const REFRESH_EVERY_MS = 60 * 60 * 1000;
/** Beta 6.3 (C2): how often the evening kudos summaries are looked for. */
export const KUDOS_ROUND_EVERY_MS = 15 * 60 * 1000;
/** Beta 6.3: cheers and nudges a day. */
export const KUDOS_PER_DAY = 500;
export const NUDGES_PER_DAY = 30;

const userParams = z.object({ userId: z.string().uuid() }).strict();
const idParams = z.object({ id: z.string().uuid() }).strict();
const clubUserParams = z.object({ id: z.string().uuid(), userId: z.string().uuid() }).strict();
const metricQuery = z.object({ metric: boardMetricSchema.default('sessions'), period: boardPeriodSchema.default('week') }).strict();
const postParams = z.object({ postId: z.string().uuid() }).strict();

const perUser = (prefix: string, max: number) => ({
  rateLimit: {
    max,
    timeWindow: '1 day',
    hook: 'preHandler' as const,
    keyGenerator: (request: FastifyRequest): string => (request.userId !== null ? `${prefix}:${request.userId}` : `${prefix}-ip:${request.ip}`),
  },
});

/**
 * Beta 6.2 (audit A2): the routes after which a member's week is recounted
 * at once (a session completed or deleted, a run saved or deleted).
 */
export const RECOUNT_AFTER: ReadonlySet<string> = new Set([
  'POST /v1/training/sessions/:id/complete',
  'POST /v1/running/runs',
  'DELETE /v1/running/runs/:id',
]);

/**
 * Registered on the /v1 scope (app.ts), so it sees the workout and running
 * routes: after a successful one, the caller's week is recounted in the
 * background when they are in Community. A failure only waits for the hourly round.
 */
export function recountOnSync(v1: FastifyInstance): void {
  const db = v1.database.db;
  const progress = new ProgressService(new ProgressRepository(db), new FoodLogRepository(db), new PlanRepository(db));
  const progressRepo = new ProgressRepository(db);
  const service = new CommunityService(
    new CommunityRepository(db),
    async (userId) => (await progress.streak(userId)).current,
    v1.push,
    () => new Date(),
    async (userId, from, to) => {
      const s = await progressRepo.trainingSchedule(userId);
      return s === null ? null : plannedBetween(s.schedule, s.training, from, to);
    },
  );
  v1.addHook('onResponse', async (request, reply) => {
    const userId = request.userId;
    if (userId === null || reply.statusCode >= 300) return;
    if (!RECOUNT_AFTER.has(`${request.method} ${request.routeOptions.url ?? ''}`)) return;
    void service.refreshIfMember(userId).catch((e: unknown) => request.log.warn({ err: e }, 'community: recount after sync failed'));
  });
}

export async function communityRoutes(app: FastifyInstance, opts: { ipSalt: string; refreshTimer: boolean }): Promise<void> {
  const db = app.database.db;
  const progress = new ProgressService(new ProgressRepository(db), new FoodLogRepository(db), new PlanRepository(db));
  const progressRepo = new ProgressRepository(db);
  const service = new CommunityService(
    new CommunityRepository(db),
    async (userId) => (await progress.streak(userId)).current,
    app.push,
    () => new Date(),
    async (userId, from, to) => {
      const s = await progressRepo.trainingSchedule(userId);
      return s === null ? null : plannedBetween(s.schedule, s.training, from, to);
    },
  );

  // Every member's week is recounted at start and every five minutes.
  const refresh = () =>
    service.refreshAll().catch((e: unknown) => {
      app.log.warn({ err: e }, 'community: refresh failed');
    });
  const kudos = () =>
    service.kudosRound().catch((e: unknown) => {
      app.log.warn({ err: e }, 'community: kudos round failed');
    });
  let timer: NodeJS.Timeout | undefined;
  let kudosTimer: NodeJS.Timeout | undefined;
  if (opts.refreshTimer) {
    app.addHook('onReady', async () => {
      void refresh();
      timer = setInterval(() => void refresh(), REFRESH_EVERY_MS);
      timer.unref();
      kudosTimer = setInterval(() => void kudos(), KUDOS_ROUND_EVERY_MS);
      kudosTimer.unref();
    });
    app.addHook('onClose', async () => {
      clearInterval(timer);
      clearInterval(kudosTimer);
    });
  }

  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 403: errorEnvelopeSchema, 404: errorEnvelopeSchema, 409: errorEnvelopeSchema, 422: errorEnvelopeSchema, 429: errorEnvelopeSchema };
  const admin = { preValidation: requireAdmin };
  const tags = ['community'];
  const on = { preHandler: async (request: FastifyRequest) => app.features.require('community', request) };
  const ip = (request: FastifyRequest) => hashIp(request.ip, opts.ipSalt);

  /* ------------------------------------------------------------ joining -- */

  typed.get('/community/me', {
    ...on,
    schema: { summary: 'Am I in Community, with which handle, and how many friend requests wait', tags, security, response: { 200: communityMeSchema, ...errors } },
  }, async (request) => service.me(requireUserId(request.userId)));

  typed.post('/community/me', {
    ...on,
    schema: {
      summary: 'Join Community with a handle (the `community` consent, to the current policy)',
      tags,
      security,
      body: joinCommunitySchema,
      response: { 201: communityMeSchema, ...errors },
    },
  }, async (request, reply) => reply.code(201).send(await service.join(requireUserId(request.userId), request.body, ip(request))));

  typed.patch('/community/me', {
    ...on,
    schema: { summary: 'Change the handle, the country or the world-board choice', tags, security, body: updateCommunitySchema, response: { 200: communityMeSchema, ...errors } },
  }, async (request) => service.update(requireUserId(request.userId), request.body));

  // Leaving works with Community switched off too: a person can always leave.
  typed.delete('/community/me', {
    schema: { summary: 'Leave Community: off every board and friends list at once (the consent withdrawn)', tags, security, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.leave(requireUserId(request.userId), ip(request));
    return reply.code(204).send(null);
  });

  /* ------------------------------------------------------------- people -- */

  typed.get('/community/people', {
    ...on,
    config: perUser('community-search', SEARCHES_PER_DAY),
    schema: { summary: 'Members whose handle starts with q (never hidden or blocked people)', tags, security, querystring: searchQuerySchema, response: { 200: personListSchema, ...errors } },
  }, async (request) => ({ items: await service.search(requireUserId(request.userId), request.query.q) }));

  typed.get('/community/people/:userId', {
    ...on,
    schema: {
      summary: "A friend's or club-mate's profile: board data only — this week, the last 4 weeks, the clubs you share (404 for anyone else)",
      tags,
      security,
      params: userParams,
      response: { 200: personProfileSchema, ...errors },
    },
  }, async (request) => service.personProfile(requireUserId(request.userId), request.params.userId));

  typed.get('/community/friends', {
    ...on,
    schema: { summary: 'Friends, requests to answer and requests waiting', tags, security, response: { 200: friendsResponseSchema, ...errors } },
  }, async (request) => service.friends(requireUserId(request.userId)));

  typed.post('/community/friends', {
    ...on,
    config: perUser('friend', FRIEND_REQUESTS_PER_DAY),
    schema: { summary: 'Ask someone to be friends by handle (accepts when they asked you first)', tags, security, body: friendRequestSchema, response: { 200: friendRequestResultSchema, ...errors } },
  }, async (request) => service.addFriend(requireUserId(request.userId), request.body.handle));

  typed.post('/community/friends/:userId/accept', {
    ...on,
    schema: { summary: "Accept someone's friend request", tags, security, params: userParams, response: { 200: friendRequestResultSchema, ...errors } },
  }, async (request) => service.accept(requireUserId(request.userId), request.params.userId));

  typed.delete('/community/friends/:userId', {
    schema: { summary: 'Decline, cancel or unfriend', tags, security, params: userParams, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.unfriend(requireUserId(request.userId), request.params.userId);
    return reply.code(204).send(null);
  });

  typed.post('/community/friends/:userId/nudge', {
    ...on,
    config: perUser('community-nudge', NUDGES_PER_DAY),
    schema: {
      summary: 'Nudge a friend who has counted nothing for 3 days: a fixed message, once a week per friend (409 active or sent)',
      tags,
      security,
      params: userParams,
      response: { 204: z.null(), ...errors },
    },
  }, async (request, reply) => {
    await service.nudge(requireUserId(request.userId), request.params.userId);
    return reply.code(204).send(null);
  });

  /* --------------------------------------------- beta 6.3: suggestions -- */

  typed.get('/community/suggestions', {
    ...on,
    schema: {
      summary: 'Friends of friends and club-mates who allow suggestions: a count of friends in common or a shared club, never who',
      tags,
      security,
      response: { 200: suggestionListSchema, ...errors },
    },
  }, async (request) => ({ items: await service.suggestions(requireUserId(request.userId)) }));

  typed.delete('/community/suggestions/:userId', {
    ...on,
    schema: { summary: 'Never suggest this person again', tags, security, params: userParams, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.dismissSuggestion(requireUserId(request.userId), request.params.userId);
    return reply.code(204).send(null);
  });

  /* ---------------------------------------------------- beta 6.3: feed -- */

  typed.get('/community/feed', {
    ...on,
    schema: {
      summary: "Your posts and your friends' (what each shares), newest first, 20 a page, from the last 14 days; nudges received",
      tags,
      security,
      querystring: feedQuerySchema,
      response: { 200: feedSchema, ...errors },
    },
  }, async (request) => service.feed(requireUserId(request.userId), request.query.before));

  typed.post('/community/feed/:postId/kudos', {
    ...on,
    config: perUser('community-kudos', KUDOS_PER_DAY),
    schema: { summary: "Cheer a friend's post (once)", tags, security, params: postParams, response: { 200: kudosResultSchema, ...errors } },
  }, async (request) => service.cheer(requireUserId(request.userId), request.params.postId, true));

  typed.delete('/community/feed/:postId/kudos', {
    ...on,
    config: perUser('community-kudos', KUDOS_PER_DAY),
    schema: { summary: 'Take a cheer back', tags, security, params: postParams, response: { 200: kudosResultSchema, ...errors } },
  }, async (request) => service.cheer(requireUserId(request.userId), request.params.postId, false));

  typed.get('/community/blocks', {
    schema: { summary: 'People you blocked', tags, security, response: { 200: personListSchema, ...errors } },
  }, async (request) => ({ items: await service.blocked(requireUserId(request.userId)) }));

  typed.post('/community/blocks', {
    schema: { summary: 'Block someone: they cannot find, add or see you, and a friendship ends', tags, security, body: blockRequestSchema, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.block(requireUserId(request.userId), request.body.userId);
    return reply.code(204).send(null);
  });

  typed.delete('/community/blocks/:userId', {
    schema: { summary: 'Unblock someone', tags, security, params: userParams, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.unblock(requireUserId(request.userId), request.params.userId);
    return reply.code(204).send(null);
  });

  /* -------------------------------------------------------------- clubs -- */

  typed.get('/community/clubs', {
    ...on,
    schema: { summary: 'Your clubs', tags, security, response: { 200: clubListSchema, ...errors } },
  }, async (request) => ({ items: await service.clubs(requireUserId(request.userId)) }));

  typed.post('/community/clubs', {
    ...on,
    config: perUser('club', CLUB_ACTIONS_PER_DAY),
    schema: { summary: 'Make a club; share its code to let people in', tags, security, body: createClubSchema, response: { 201: clubSchema, ...errors } },
  }, async (request, reply) => reply.code(201).send(await service.createClub(requireUserId(request.userId), request.body.name)));

  typed.post('/community/clubs/join', {
    ...on,
    config: perUser('club', CLUB_ACTIONS_PER_DAY),
    schema: { summary: 'Join a club with its code', tags, security, body: joinClubSchema, response: { 200: clubSchema, ...errors } },
  }, async (request) => service.joinClub(requireUserId(request.userId), request.body.code));

  typed.delete('/community/clubs/:id/membership', {
    schema: { summary: 'Leave a club (one you made passes to its longest member)', tags, security, params: idParams, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.leaveClub(requireUserId(request.userId), request.params.id);
    return reply.code(204).send(null);
  });

  /* ------------------------------------------- beta 6.2 (C5): the owner -- */

  const owner = { ...on, config: perUser('club-owner', CLUB_OWNER_ACTIONS_PER_DAY) };

  typed.patch('/community/clubs/:id', {
    ...owner,
    schema: { summary: 'Rename a club you own', tags, security, params: idParams, body: renameClubSchema, response: { 200: clubSchema, ...errors } },
  }, async (request) => service.renameClub(requireUserId(request.userId), request.params.id, request.body.name));

  typed.post('/community/clubs/:id/code', {
    ...owner,
    schema: { summary: 'A new code for a club you own (the old one stops working)', tags, security, params: idParams, response: { 200: clubSchema, ...errors } },
  }, async (request) => service.newClubCode(requireUserId(request.userId), request.params.id));

  typed.post('/community/clubs/:id/owner', {
    ...owner,
    schema: { summary: 'Pass a club you own to another member', tags, security, params: idParams, body: passClubSchema, response: { 200: clubSchema, ...errors } },
  }, async (request) => service.passClub(requireUserId(request.userId), request.params.id, request.body.userId));

  typed.delete('/community/clubs/:id/members/:userId', {
    ...owner,
    schema: { summary: 'Remove a member from a club you own; they cannot rejoin with the code until let back', tags, security, params: clubUserParams, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.removeMember(requireUserId(request.userId), request.params.id, request.params.userId);
    return reply.code(204).send(null);
  });

  typed.get('/community/clubs/:id/removed', {
    ...on,
    schema: { summary: 'People removed from a club you own', tags, security, params: idParams, response: { 200: personListSchema, ...errors } },
  }, async (request) => ({ items: await service.removedFrom(requireUserId(request.userId), request.params.id) }));

  typed.delete('/community/clubs/:id/removed/:userId', {
    ...owner,
    schema: { summary: 'Let someone back: they can join again with the code', tags, security, params: clubUserParams, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.letBack(requireUserId(request.userId), request.params.id, request.params.userId);
    return reply.code(204).send(null);
  });

  /* ------------------------------------------------------------- boards -- */

  typed.get('/community/boards/friends', {
    ...on,
    schema: { summary: 'You and your friends this week, this month or since joining', tags, security, querystring: metricQuery, response: { 200: boardSchema, ...errors } },
  }, async (request) => service.friendsBoard(requireUserId(request.userId), request.query.metric, request.query.period));

  typed.get('/community/boards/clubs/:id', {
    ...on,
    schema: { summary: "A club's members this week, this month or since joining", tags, security, params: idParams, querystring: metricQuery, response: { 200: boardSchema, ...errors } },
  }, async (request) => service.clubBoard(requireUserId(request.userId), request.params.id, request.query.metric, request.query.period));

  typed.get('/community/boards/world', {
    ...on,
    schema: {
      summary: 'The top 100 this week who chose to be on the world board, worldwide or in one country, and your place',
      tags,
      security,
      querystring: boardQuerySchema,
      response: { 200: boardSchema, ...errors },
    },
  }, async (request) => service.worldBoard(requireUserId(request.userId), request.query.metric, request.query.country ?? null, request.query.period));

  /* ------------------------------------------------------------ reports -- */

  typed.post('/community/reports', {
    ...on,
    config: perUser('community-report', REPORTS_PER_DAY),
    schema: { summary: 'Report a handle, a club name, cheating or harassment to the FITOS team', tags, security, body: reportRequestSchema, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.report(requireUserId(request.userId), request.body);
    return reply.code(204).send(null);
  });

  /* -------------------------------------------------------------- admin -- */

  typed.get('/admin/community/reports', {
    ...admin,
    schema: { summary: 'Community reports, newest first', tags: ['admin'], security, querystring: adminCommunityReportQuerySchema, response: { 200: adminCommunityReportListSchema, ...errors } },
  }, async (request) => service.adminReports(request.query.status));

  typed.post('/admin/community/reports/:id/close', {
    ...admin,
    schema: { summary: 'Close a report (audited)', tags: ['admin'], security, params: idParams, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.closeReport(request.userId, request.params.id);
    return reply.code(204).send(null);
  });

  typed.get('/admin/community/members', {
    ...admin,
    schema: { summary: 'Community members, newest first (handle search)', tags: ['admin'], security, querystring: adminCommunityMemberQuerySchema, response: { 200: adminCommunityMemberListSchema, ...errors } },
  }, async (request) => service.adminMembers(request.query.q));

  typed.patch('/admin/community/members/:userId', {
    ...admin,
    schema: { summary: 'Hide a member from boards and search, or rename an unsuitable handle (audited)', tags: ['admin'], security, params: userParams, body: adminUpdateMemberSchema, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.adminUpdateMember(request.userId, request.params.userId, request.body);
    return reply.code(204).send(null);
  });

  typed.get('/admin/community/clubs', {
    ...admin,
    schema: { summary: 'Clubs, newest first', tags: ['admin'], security, response: { 200: adminClubListSchema, ...errors } },
  }, async () => service.adminClubs());

  typed.delete('/admin/community/clubs/:id', {
    ...admin,
    schema: { summary: 'Delete a club (audited)', tags: ['admin'], security, params: idParams, response: { 204: z.null(), ...errors } },
  }, async (request, reply) => {
    await service.adminDeleteClub(request.userId, request.params.id);
    return reply.code(204).send(null);
  });
}
