/**
 * Beta 4.5 (owner 2026-10-30) on real Postgres: runs from a Galaxy Watch
 * (Health Connect) — imported once by their record id, with heart rate,
 * with or without their route — and the speed, lifetime and consistency
 * badges, sent only to builds that read them.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { rewardsResponseSchema, runDetailSchema, runningRecordsSchema, type CreateRunRequest } from '@fitos/contracts';
import { encodeTrack, type TrackPoint } from '@fitos/core/running/track';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;
const M_PER_DEG = (Math.PI / 180) * 6_371_008.8;

describeIfDb('beta 4.5 (real Postgres)', { timeout: 90_000 }, () => {
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
    await sql`delete from users where firebase_uid like 'b45-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
  }
  const headers = (u: U, build?: number) => ({
    authorization: `Bearer ${u.token}`,
    'x-forwarded-for': `203.0.193.${n % 250}`,
    ...(build === undefined ? {} : { 'x-fitos-build': String(build) }),
  });

  async function user(): Promise<U> {
    n += 1;
    const token = `b45-tok-${n}`;
    verifier.accept(token, { uid: `b45-uid-${n}`, email: `b45-${n}@vit.ac.in` });
    const u = { token, id: '' };
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(u), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`b45-uid-${n}`}`;
    return { token, id: row!.id };
  }

  const call = (u: U, method: 'GET' | 'POST', path: string, payload?: unknown, build?: number) =>
    app.inject({ method, url: `/v1${path}`, headers: headers(u, build), ...(payload === undefined ? {} : { payload: payload as object }) });

  const daysAgo = (d: number) => new Date(Date.now() - d * 86_400_000);

  function watchRun(startedAt: Date, over: Partial<CreateRunRequest> = {}): CreateRunRequest {
    return {
      clientRunId: randomUUID(),
      kind: 'outdoor',
      name: 'Galaxy Watch run',
      startedAt: startedAt.toISOString(),
      endedAt: new Date(startedAt.getTime() + 1800_000).toISOString(),
      durationSeconds: 1800,
      goal: { kind: 'free', value: null },
      source: 'watch',
      externalId: `hc-${randomUUID()}`,
      distanceM: 5200,
      hrAvg: 152,
      hrMax: 178,
      ...over,
    };
  }

  function tracked(metres: number, pace: number, startedAt: Date, over: Partial<CreateRunRequest> = {}): CreateRunRequest {
    const points: TrackPoint[] = [];
    for (let m = 0; m <= metres + 1e-9; m += 10) {
      points.push({ t: Math.round((m / 1000) * pace * 10) / 10, lat: 12.97 + m / M_PER_DEG, lon: 79.16, ele: null });
    }
    const seconds = Math.round((metres / 1000) * pace);
    const track = encodeTrack({ segments: [points] });
    return {
      clientRunId: randomUUID(),
      kind: 'outdoor',
      name: 'Fast one',
      startedAt: startedAt.toISOString(),
      endedAt: new Date(startedAt.getTime() + (seconds + 60) * 1000).toISOString(),
      durationSeconds: seconds,
      goal: { kind: 'free', value: null },
      track: { ...track, breaks: [...track.breaks] },
      ...over,
    };
  }

  describe('watch runs', () => {
    it('a watch run without a route: the watch’s distance and heart rate, marked as from the watch; imported once', async () => {
      const u = await user();
      const req = watchRun(daysAgo(2));
      const first = await call(u, 'POST', '/running/runs', req);
      expect(first.statusCode, first.body).toBe(201);
      const run = runDetailSchema.parse(first.json());
      expect(run).toMatchObject({ source: 'watch', hrAvg: 152, hrMax: 178, track: null, distanceM: 5200 });
      expect(run.efforts).toEqual([]);
      // The same Health Connect record again (another phone, a reinstall): that run, not a new one.
      const again = await call(u, 'POST', '/running/runs', { ...req, clientRunId: randomUUID() });
      expect(again.statusCode).toBe(200);
      expect(runDetailSchema.parse(again.json()).id).toBe(run.id);
      const [count] = await sql<{ n: number }[]>`select count(*)::int as n from runs where user_id = ${u.id}`;
      expect(count!.n).toBe(1);
    });

    it('a watch run with its route: figures from the route, best efforts, heart rate kept', async () => {
      const u = await user();
      const req = tracked(5010, 300, daysAgo(3), { source: 'watch', externalId: 'hc-route-1', hrAvg: 140, hrMax: 165 });
      const run = runDetailSchema.parse((await call(u, 'POST', '/running/runs', req)).json());
      expect(run.source).toBe('watch');
      expect(run.track).not.toBeNull();
      expect(run.efforts.map((e) => e.key)).toContain('5k');
    });

    it('refuses what a watch run cannot be', async () => {
      const u = await user();
      const bad = async (over: Partial<CreateRunRequest>) => (await call(u, 'POST', '/running/runs', watchRun(daysAgo(1), over))).statusCode;
      expect(await bad({ externalId: undefined })).toBe(422);
      expect(await bad({ distanceM: undefined })).toBe(422);
      expect(await bad({ hrMax: 400 })).toBe(422);
      // Heart rate only from a watch; a phone run outdoors still needs its track.
      expect(await bad({ source: 'phone', externalId: undefined })).toBe(422);
      expect(await bad({ source: undefined, externalId: undefined, hrAvg: undefined, hrMax: undefined })).toBe(422);
    });
  });

  describe('beta 4.9: cadence and race runs (owner)', () => {
    it('a watch run carries its cadence; a phone run cannot; out-of-range cadence is refused', async () => {
      const u = await user();
      const run = runDetailSchema.parse((await call(u, 'POST', '/running/runs', watchRun(daysAgo(4), { cadenceAvg: 168, cadenceMax: 182 }))).json());
      expect(run).toMatchObject({ cadenceAvg: 168, cadenceMax: 182 });
      const bad = async (over: Partial<CreateRunRequest>) => (await call(u, 'POST', '/running/runs', watchRun(daysAgo(5), over))).statusCode;
      expect(await bad({ cadenceAvg: 300 })).toBe(422);
      expect(await bad({ source: 'phone', externalId: undefined, hrAvg: undefined, hrMax: undefined, cadenceAvg: 170 })).toBe(422);
    });

    it('a race run keeps its distance, target time and split; only a race has them', async () => {
      const u = await user();
      const race = { kind: 'race' as const, value: 5000, targetSeconds: 1500, split: 'negative' as const };
      const run = runDetailSchema.parse((await call(u, 'POST', '/running/runs', watchRun(daysAgo(6), { goal: race }))).json());
      expect(run.goal).toEqual(race);
      const bad = async (goal: unknown) => (await call(u, 'POST', '/running/runs', watchRun(daysAgo(7), { goal: goal as never }))).statusCode;
      expect(await bad({ kind: 'race', value: 5000 })).toBe(422);
      expect(await bad({ kind: 'distance', value: 5000, targetSeconds: 1500, split: 'even' })).toBe(422);
      expect(await bad({ ...race, split: 'fast' })).toBe(422);
      expect(await bad({ ...race, value: 500 })).toBe(422);
    });
  });

  describe('more badges', () => {
    it('lifetime and consistency from past runs; the total on records; only for build 23+', async () => {
      const u = await user();
      // Five 200 km "treadmill" days in one week: 1,000 km, three runs in a week.
      const monday = new Date(Date.UTC(2026, 9, 5, 2));
      for (let i = 0; i < 5; i++) {
        const at = new Date(monday.getTime() + i * 86_400_000);
        const r = await call(u, 'POST', '/running/runs', {
          clientRunId: randomUUID(),
          kind: 'treadmill',
          name: 'Long',
          startedAt: at.toISOString(),
          endedAt: new Date(at.getTime() + 3600_000).toISOString(),
          durationSeconds: 3600,
          goal: { kind: 'free', value: null },
          distanceM: 200_000,
        } satisfies CreateRunRequest);
        expect(r.statusCode).toBe(201);
      }
      const rec = runningRecordsSchema.parse((await call(u, 'GET', '/running/records')).json());
      expect(rec.totalM).toBe(1_000_000);

      const earned = rewardsResponseSchema.parse((await call(u, 'GET', '/user/rewards', undefined, 23)).json()).earned;
      const ids = earned.map((e) => e.id);
      expect(ids).toEqual(expect.arrayContaining(['total-50k', 'total-100k', 'total-250k', 'total-500k', 'total-1000k', 'three-in-a-week']));
      expect(ids).not.toContain('weeks-4');
      // 1,000 km on the fifth day.
      expect(earned.find((e) => e.id === 'total-1000k')!.earnedAt).toBe(new Date(monday.getTime() + 4 * 86_400_000).toISOString());
      // A 4.4 phone (build 22) sees the 4.2 badges, not these.
      const old = rewardsResponseSchema.parse((await call(u, 'GET', '/user/rewards', undefined, 22)).json()).earned.map((e) => e.id);
      expect(old).toContain('first-run');
      expect(old).not.toContain('total-1000k');
    });

    it('speed: a 5K under 20 minutes (from the route’s best effort)', async () => {
      const u = await user();
      expect((await call(u, 'POST', '/running/runs', tracked(5010, 234, daysAgo(1)))).statusCode).toBe(201);
      const ids = rewardsResponseSchema.parse((await call(u, 'GET', '/user/rewards', undefined, 23)).json()).earned.map((e) => e.id);
      expect(ids).toEqual(expect.arrayContaining(['speed-5k-30', 'speed-5k-25', 'speed-5k-20']));
    });
  });
});
