/**
 * Beta 4.2 (owner 2026-10-29): best efforts and the distance badges. Drizzle
 * only; every query is scoped to one user.
 *
 * A run's efforts are core's (running/efforts.ts), worked out when the run
 * is saved; older runs, and runs worked out by older rules
 * (`runs.efforts_version`), a batch at a time when the records are read.
 */
import { and, asc, eq, lt, sql } from 'drizzle-orm';
import { localDateOf } from '@fitos/core/nutrition/log';
import { consistencyBadges, lifetimeBadges, speedBadges, type MoreBadgeId } from '@fitos/core/running/badges';
import { BADGE_SLACK_M, DISTANCE_BADGES, type BestEffort, type EffortKey } from '@fitos/core/running/efforts';

import type { DatabaseHandle } from '../../db/client.js';
import { plannedRuns, runBestEfforts, runs, userRewards, users, type RunRow } from '../../db/schema.js';

type Db = DatabaseHandle['db'];

export interface RankedEffort {
  readonly key: EffortKey;
  readonly seconds: number;
  readonly startM: number;
  /** 1 = the record; 2 and 3; null below the third. */
  readonly rank: number | null;
}

export interface RecordRow {
  readonly key: EffortKey;
  readonly clientRunId: string;
  readonly name: string;
  readonly startedAt: Date;
  readonly seconds: number;
}

export class EffortsRepository {
  constructor(private readonly db: Db) {}

  /** Outdoor runs whose efforts are missing or from older rules, oldest first. */
  async stale(userId: string, version: number, limit: number): Promise<RunRow[]> {
    return this.db
      .select()
      .from(runs)
      .where(and(eq(runs.userId, userId), eq(runs.kind, 'outdoor'), lt(runs.effortsVersion, version)))
      .orderBy(asc(runs.startedAt), asc(runs.id))
      .limit(limit);
  }

  async staleCount(userId: string, version: number): Promise<number> {
    const [row] = await this.db
      .select({ n: sql<number>`count(*)::int` })
      .from(runs)
      .where(and(eq(runs.userId, userId), eq(runs.kind, 'outdoor'), lt(runs.effortsVersion, version)));
    return row!.n;
  }

  /** A run's efforts, replacing any older ones, and the rules' version on the run. */
  async replace(runId: string, userId: string, efforts: readonly BestEffort[], version: number): Promise<void> {
    await this.db.transaction(async (tx) => {
      await tx.delete(runBestEfforts).where(eq(runBestEfforts.runId, runId));
      if (efforts.length > 0) {
        await tx.insert(runBestEfforts).values(
          efforts.map((e) => ({ runId, userId, key: e.key, seconds: e.seconds.toFixed(1), startM: e.startM.toFixed(1) })),
        );
      }
      await tx.update(runs).set({ effortsVersion: version }).where(eq(runs.id, runId));
    });
  }

  /**
   * One run's efforts, each ranked among all the user's at that distance
   * (ties: the earlier run first).
   */
  async ranked(userId: string, runId: string): Promise<RankedEffort[]> {
    const rows = await this.db.execute<{ key: EffortKey; seconds: string; start_m: string; rank: number }>(sql`
      select e.key, e.seconds, e.start_m,
        (select count(*)::int + 1
           from ${runBestEfforts} o join ${runs} r on r.id = o.run_id
          where o.user_id = ${userId} and o.key = e.key and o.run_id <> e.run_id
            and (o.seconds < e.seconds or (o.seconds = e.seconds and r.started_at < me.started_at))) as rank
      from ${runBestEfforts} e join ${runs} me on me.id = e.run_id
      where e.run_id = ${runId} and e.user_id = ${userId}
      order by array_position(enum_range(null::effort_key), e.key)`);
    return rows.map((r) => ({
      key: r.key,
      seconds: Number(r.seconds),
      startM: Number(r.start_m),
      rank: r.rank <= 3 ? r.rank : null,
    }));
  }

  /** The best three at each distance (ties: the earlier run first). */
  async top3(userId: string): Promise<RecordRow[]> {
    const rows = await this.db.execute<{ key: EffortKey; client_run_id: string; name: string; started_at: string | Date; seconds: string }>(sql`
      select key, client_run_id, name, started_at, seconds from (
        select e.key, r.client_run_id, r.name, r.started_at, e.seconds,
               row_number() over (partition by e.key order by e.seconds, r.started_at, r.id) as n
          from ${runBestEfforts} e join ${runs} r on r.id = e.run_id
         where e.user_id = ${userId}) t
      where n <= 3
      order by array_position(enum_range(null::effort_key), key), n`);
    return rows.map((r) => ({
      key: r.key,
      clientRunId: r.client_run_id,
      name: r.name,
      startedAt: new Date(r.started_at),
      seconds: Number(r.seconds),
    }));
  }

  /** For each run id given, the distances it holds the record for. */
  async recordKeys(userId: string, runIds: readonly string[]): Promise<Map<string, EffortKey[]>> {
    const out = new Map<string, EffortKey[]>();
    if (runIds.length === 0) return out;
    const rows = await this.db.execute<{ key: EffortKey; run_id: string }>(sql`
      select distinct on (e.key) e.key, e.run_id
        from ${runBestEfforts} e join ${runs} r on r.id = e.run_id
       where e.user_id = ${userId}
       order by e.key, e.seconds, r.started_at, r.id`);
    const wanted = new Set(runIds);
    for (const r of rows) {
      if (!wanted.has(r.run_id)) continue;
      out.set(r.run_id, [...(out.get(r.run_id) ?? []), r.key]);
    }
    return out;
  }

  /** Beta 4.3: the longest single run in metres (0 with none), treadmill too. */
  async longest(userId: string): Promise<number> {
    const [row] = await this.db
      .select({ m: sql<string>`coalesce(max(${runs.distanceM}), 0)` })
      .from(runs)
      .where(eq(runs.userId, userId));
    return Number(row!.m);
  }

  /**
   * The distance firsts any run reached, each dated by the first run that
   * reached it, kept once (a badge stays if that run is deleted later).
   * Returns the ids new this time.
   */
  /** Beta 4.5: every run's distance added up, metres. */
  async total(userId: string): Promise<number> {
    const [row] = await this.db
      .select({ m: sql<string>`coalesce(sum(${runs.distanceM}), 0)` })
      .from(runs)
      .where(eq(runs.userId, userId));
    return Number(row!.m);
  }

  /** Beta 4.5: the speed, lifetime and consistency badges the user's runs reached. */
  private async moreBadges(userId: string): Promise<[MoreBadgeId, Date][]> {
    const [user] = await this.db.select({ tz: users.timezone }).from(users).where(eq(users.id, userId)).limit(1);
    const tz = user?.tz ?? 'Asia/Kolkata';
    const [rows, efforts, finished] = await Promise.all([
      this.db.select({ startedAt: runs.startedAt, distanceM: runs.distanceM }).from(runs).where(eq(runs.userId, userId)),
      this.db
        .select({ key: runBestEfforts.key, seconds: runBestEfforts.seconds, startedAt: runs.startedAt })
        .from(runBestEfforts)
        .innerJoin(runs, eq(runs.id, runBestEfforts.runId))
        .where(eq(runBestEfforts.userId, userId)),
      // A plan is finished when its race run is done (dated by that run).
      this.db
        .select({ at: sql<string | Date | null>`min(${runs.startedAt})` })
        .from(plannedRuns)
        .innerJoin(runs, eq(runs.id, plannedRuns.runId))
        .where(and(eq(plannedRuns.userId, userId), eq(plannedRuns.kind, 'race'), eq(plannedRuns.status, 'done'))),
    ]);
    const badgeRuns = rows.map((r) => ({ startedAt: r.startedAt, localDate: localDateOf(r.startedAt, tz), distanceM: Number(r.distanceM) }));
    const planAt = finished[0]?.at;
    return [
      ...speedBadges(efforts.map((e) => ({ key: e.key, seconds: Number(e.seconds), startedAt: e.startedAt }))),
      ...lifetimeBadges(badgeRuns),
      ...consistencyBadges(badgeRuns, planAt === null || planAt === undefined ? null : new Date(planAt)),
    ];
  }

  async awardBadges(userId: string): Promise<string[]> {
    const firsts = await this.db.execute<Record<string, string | Date | null>>(sql`
      select ${sql.join(
        DISTANCE_BADGES.map(
          (b, i) => sql`min(started_at) filter (where distance_m >= ${Math.max(0, b.metres - BADGE_SLACK_M)}) as ${sql.raw(`b${i}`)}`,
        ),
        sql`, `,
      )}
      from ${runs} where user_id = ${userId}`);
    const row = firsts[0]!;
    const reached: { userId: string; reward: string; earnedAt: Date }[] = DISTANCE_BADGES.flatMap((b, i) => {
      const at = row[`b${i}`];
      return at === null || at === undefined ? [] : [{ userId, reward: b.id, earnedAt: new Date(at) }];
    });
    // Beta 4.5: speed, lifetime and consistency (core running/badges.ts).
    for (const [reward, earnedAt] of await this.moreBadges(userId)) reached.push({ userId, reward, earnedAt });
    if (reached.length === 0) return [];
    const inserted = await this.db
      .insert(userRewards)
      .values(reached)
      .onConflictDoNothing({ target: [userRewards.userId, userRewards.reward] })
      .returning({ reward: userRewards.reward });
    return inserted.map((r) => r.reward);
  }
}
