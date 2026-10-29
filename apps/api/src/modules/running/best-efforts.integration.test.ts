/**
 * Beta 4.2 (owner 2026-10-29) on real Postgres: best efforts worked out when
 * a run is saved and ranked among the user's; the records (the best three
 * at each distance), older runs filled in when the records are read; the
 * history's trophy; deleting a run; the distance firsts, dated by the first
 * run that reached them and kept; and the badges only for builds that read
 * them (GET /user/rewards checks ids strictly on older phones).
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import {
  RUNNING_BADGES_MIN_BUILD,
  rewardsResponseSchema,
  runDetailSchema,
  runListSchema,
  runningRecordsSchema,
  type CreateRunRequest,
} from '@fitos/contracts';
import { EFFORTS_VERSION } from '@fitos/core/running/efforts';
import { encodeTrack, type TrackPoint } from '@fitos/core/running/track';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

const M_PER_DEG = (Math.PI / 180) * 6_371_008.8;

/** A straight run north of [metres] at [pace] s/km, a point every 10 m. */
function track(metres: number, pace: number): { points: TrackPoint[]; seconds: number } {
  const points: TrackPoint[] = [];
  for (let m = 0; m <= metres + 1e-9; m += 10) {
    points.push({ t: Math.round((m / 1000) * pace * 10) / 10, lat: 12.97 + m / M_PER_DEG, lon: 79.16, ele: null });
  }
  return { points, seconds: Math.round((metres / 1000) * pace) };
}

describeIfDb('best efforts and distance badges (real Postgres)', { timeout: 90_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    await sql`delete from feature_flags where key = 'running'`;
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'pb-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
  }
  const headers = (u: U, build?: number) => ({
    authorization: `Bearer ${u.token}`,
    'x-forwarded-for': `203.0.191.${n % 250}`,
    ...(build === undefined ? {} : { 'x-fitos-build': String(build) }),
  });

  async function user(): Promise<U> {
    n += 1;
    const token = `pb-tok-${n}`;
    verifier.accept(token, { uid: `pb-uid-${n}`, email: `pb${n}@vit.ac.in` });
    const u = { token, id: '' };
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(u), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`pb-uid-${n}`}`;
    return { token, id: row!.id };
  }

  const call = (u: U, method: 'GET' | 'POST' | 'DELETE', path: string, payload?: unknown, build?: number) =>
    app.inject({ method, url: `/v1${path}`, headers: headers(u, build), ...(payload === undefined ? {} : { payload: payload as object }) });

  function outdoor(metres: number, pace: number, startedAt: Date, name = 'Run'): CreateRunRequest {
    const t = track(metres, pace);
    const encoded = encodeTrack({ segments: [t.points] });
    return {
      clientRunId: randomUUID(),
      kind: 'outdoor',
      name,
      startedAt: startedAt.toISOString(),
      endedAt: new Date(startedAt.getTime() + (t.seconds + 60) * 1000).toISOString(),
      durationSeconds: t.seconds,
      goal: { kind: 'free', value: null },
      track: { ...encoded, breaks: [...encoded.breaks] },
    };
  }

  const daysAgo = (d: number) => new Date(Date.now() - d * 86_400_000);
  const save = async (u: U, req: CreateRunRequest) => {
    const r = await call(u, 'POST', '/running/runs', req);
    expect(r.statusCode).toBe(201);
    return runDetailSchema.parse(r.json());
  };
  const records = async (u: U) => {
    const r = await call(u, 'GET', '/running/records');
    expect(r.statusCode).toBe(200);
    return runningRecordsSchema.parse(r.json());
  };
  const rewards = async (u: U, build?: number) => rewardsResponseSchema.parse((await call(u, 'GET', '/user/rewards', undefined, build)).json());

  it('a saved run has its best efforts, each ranked; a faster run takes the record; the history shows who holds it', async () => {
    const u = await user();
    const first = await save(u, outdoor(6010, 300, daysAgo(3), 'Easy six'));
    expect(first.efforts.map((e) => e.key)).toEqual(['400m', '1k', '1mile', '5k']);
    expect(first.efforts.every((e) => e.rank === 1)).toBe(true);
    expect(first.efforts.find((e) => e.key === '5k')!.seconds).toBeCloseTo(1500, 0);
    expect(first.recordKeys).toEqual(['400m', '1k', '1mile', '5k']);

    const second = await save(u, outdoor(5010, 270, daysAgo(1), 'Tempo'));
    expect(second.efforts.find((e) => e.key === '5k')).toMatchObject({ rank: 1 });
    expect(second.efforts.find((e) => e.key === '5k')!.seconds).toBeCloseTo(1350, 0);

    const again = runDetailSchema.parse((await call(u, 'GET', `/running/runs/${first.id}`)).json());
    expect(again.efforts.find((e) => e.key === '5k')!.rank).toBe(2);
    expect(again.recordKeys).toEqual([]);

    const list = runListSchema.parse((await call(u, 'GET', '/running/runs')).json());
    expect(list.runs.find((r) => r.id === second.id)!.recordKeys).toEqual(['400m', '1k', '1mile', '5k']);
    expect(list.runs.find((r) => r.id === first.id)!.recordKeys).toEqual([]);

    const rec = await records(u);
    expect(rec.records.map((r) => r.key)).toEqual(['400m', '1k', '1mile', '5k', '10k', 'half', 'marathon']);
    const five = rec.records.find((r) => r.key === '5k')!.best;
    expect(five.map((b) => b.name)).toEqual(['Tempo', 'Easy six']);
    expect(rec.records.find((r) => r.key === '10k')!.best).toEqual([]);
    expect(rec.pending).toBe(0);
  });

  it('deleting the record run: its efforts go and the next best is the record', async () => {
    const u = await user();
    const slow = await save(u, outdoor(5010, 330, daysAgo(4), 'Slow'));
    const fast = await save(u, outdoor(5010, 280, daysAgo(2), 'Fast'));
    expect((await call(u, 'DELETE', `/running/runs/${fast.id}`)).statusCode).toBe(204);
    const five = (await records(u)).records.find((r) => r.key === '5k')!.best;
    expect(five.map((b) => b.runId)).toEqual([slow.id]);
    const [{ n: left }] = await sql<{ n: number }[]>`select count(*)::int as n from run_best_efforts where user_id = ${u.id}`;
    expect(left).toBe(4);
  });

  it('older runs (saved before 4.2) are worked out when the records are read', async () => {
    const u = await user();
    const run = await save(u, outdoor(1210, 300, daysAgo(10), 'Old'));
    // As a 4.1 server left it: no efforts, rules version 0.
    await sql`delete from run_best_efforts where user_id = ${u.id}`;
    await sql`update runs set efforts_version = 0 where user_id = ${u.id}`;
    const rec = await records(u);
    expect(rec.records.find((r) => r.key === '1k')!.best.map((b) => b.runId)).toEqual([run.id]);
    expect(rec.pending).toBe(0);
    const [row] = await sql<{ v: number }[]>`select efforts_version as v from runs where user_id = ${u.id}`;
    expect(row!.v).toBe(EFFORTS_VERSION);
  });

  it('distance firsts: a treadmill run counts; dated by the first run; kept when that run is deleted; only for builds that read them', async () => {
    const u = await user();
    const treadmillAt = daysAgo(6);
    const t = await call(u, 'POST', '/running/runs', {
      clientRunId: randomUUID(),
      kind: 'treadmill',
      name: 'Treadmill',
      startedAt: treadmillAt.toISOString(),
      endedAt: new Date(treadmillAt.getTime() + 3700_000).toISOString(),
      durationSeconds: 3600,
      goal: { kind: 'free', value: null },
      distanceM: 10_200,
    } satisfies CreateRunRequest);
    expect(t.statusCode).toBe(201);
    // Efforts need a track: a treadmill run has none.
    expect(runDetailSchema.parse(t.json()).efforts).toEqual([]);

    const now = await rewards(u, RUNNING_BADGES_MIN_BUILD);
    expect(now.earned.map((e) => e.id).sort()).toEqual(['first-10k', 'first-5k', 'first-run']);
    expect(now.earned.find((e) => e.id === 'first-10k')!.earnedAt).toBe(treadmillAt.toISOString());

    // Older phones never see them (strict ids), with or without the header.
    expect((await rewards(u)).earned).toEqual([]);
    expect((await rewards(u, RUNNING_BADGES_MIN_BUILD - 1)).earned).toEqual([]);

    // Kept even when the run that earned them is gone.
    expect((await call(u, 'DELETE', `/running/runs/${runDetailSchema.parse(t.json()).id}`)).statusCode).toBe(204);
    expect((await rewards(u, RUNNING_BADGES_MIN_BUILD)).earned).toHaveLength(3);
  });

  it('past runs earn their badges once read, a run of 4.995 km reads as 5 km, and other people never count', async () => {
    const u = await user();
    const other = await user();
    await save(other, outdoor(21_110, 300, daysAgo(2), 'Their half'));
    await save(u, outdoor(5000, 300, daysAgo(3), 'Almost five'));
    // As a 4.1 server left it: no badges yet.
    await sql`delete from user_rewards where user_id = ${u.id}`;
    const earned = (await rewards(u, 25)).earned.map((e) => e.id).sort();
    // A straight 5,000 m track measures a hair under 5 km: still 5 km.
    expect(earned).toEqual(['first-5k', 'first-run']);
    expect((await records(u)).records.find((r) => r.key === 'half')!.best).toEqual([]);
  });
});
