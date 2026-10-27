/**
 * /v1/running on real Postgres (beta 4.0, ADR-038): a finished run saved
 * once (replays answer the same run), every figure computed here from the
 * track and equal to core's, treadmill runs, a track that does not decode,
 * the history with this week's and this month's totals, edits, deletion,
 * other people's runs, and the admin's switch.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { runDetailSchema, runListSchema, type CreateRunRequest, type RunDetail, type RunList } from '@fitos/contracts';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';
import { summarizeTrack, type RunSummary } from '@fitos/core/running/summary';
import { decodeTrack, type EncodedTrack } from '@fitos/core/running/track';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

const fixtures = join(dirname(fileURLToPath(import.meta.url)), '../../../../../packages/core/test/fixtures/running');
interface Fixture {
  track: EncodedTrack;
  durationSeconds: number;
  weightKg: number | null;
  expected: RunSummary;
}
const fixture = (name: string): Fixture => JSON.parse(readFileSync(join(fixtures, `${name}.json`), 'utf8')) as Fixture;

describeIfDb('/v1/running (real Postgres)', { timeout: 90_000 }, () => {
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
    await sql`delete from feature_flags where key = 'running'`;
    await sql`delete from users where firebase_uid like 'rn-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
  }
  const auth = (u: U) => ({ authorization: `Bearer ${u.token}`, 'x-forwarded-for': `203.0.190.${n % 250}` });

  async function user(tz = 'Asia/Kolkata'): Promise<U> {
    n += 1;
    const token = `rn-tok-${n}`;
    verifier.accept(token, { uid: `rn-uid-${n}`, email: `rn${n}@vit.ac.in` });
    const u = { token, id: '' };
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(u), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`rn-uid-${n}`}`;
    await sql`update users set timezone = ${tz} where id = ${row!.id}`;
    return { token, id: row!.id };
  }

  const call = (u: U, method: 'GET' | 'POST' | 'PATCH' | 'DELETE', path: string, payload?: unknown) =>
    app.inject({ method, url: `/v1${path}`, headers: auth(u), ...(payload === undefined ? {} : { payload: payload as object }) });

  function outdoor(name: string, startedAt: Date, over: Partial<CreateRunRequest> = {}): CreateRunRequest {
    const f = fixture(name);
    return {
      clientRunId: randomUUID(),
      kind: 'outdoor',
      name: 'Morning run',
      startedAt: startedAt.toISOString(),
      endedAt: new Date(startedAt.getTime() + (f.durationSeconds + 600) * 1000).toISOString(),
      durationSeconds: f.durationSeconds,
      goal: { kind: 'distance', value: 5000 },
      track: { ...f.track, breaks: [...f.track.breaks] },
      ...over,
    };
  }

  const hoursAgo = (h: number) => new Date(Date.now() - h * 3600_000);

  it('saves a run once: every figure is core’s, computed from the track', async () => {
    const u = await user();
    const req = outdoor('easy-loop', hoursAgo(2), { note: 'Felt good', effort: 4 });
    const first = await call(u, 'POST', '/running/runs', req);
    expect(first.statusCode).toBe(201);
    const run = runDetailSchema.parse(first.json());
    const f = fixture('easy-loop');
    const core = summarizeTrack(decodeTrack(f.track), f.durationSeconds, null);
    expect(run).toMatchObject({
      id: req.clientRunId,
      kind: 'outdoor',
      name: 'Morning run',
      note: 'Felt good',
      effort: 4,
      goal: { kind: 'distance', value: 5000 },
      durationSeconds: f.durationSeconds,
      distanceM: core.distanceM,
      avgPaceSecPerKm: core.avgPaceSecPerKm,
      elevationGainM: core.elevationGainM,
      // No weight on file: no calorie figure.
      calories: null,
      track: f.track,
    });
    expect(run.splitsKm).toEqual(core.splitsKm);
    expect(run.splitsMi).toEqual(core.splitsMi);
    expect(run.series).toEqual(core.series);
    expect(run.outline).toEqual(core.outline);

    // The phone sends it again (a retry after a lost answer): the same run, nothing new.
    const again = await call(u, 'POST', '/running/runs', { ...req, name: 'Changed in flight' });
    expect(again.statusCode).toBe(200);
    expect(again.json<RunDetail>().name).toBe('Morning run');
    const [count] = await sql<{ n: number }[]>`select count(*)::int as n from runs where user_id = ${u.id}`;
    expect(count!.n).toBe(1);

    // Someone else using the same id is refused.
    expect((await call(await user(), 'POST', '/running/runs', req)).statusCode).toBe(409);
  });

  it('calories use the weight on the run’s day', async () => {
    const u = await user();
    const started = hoursAgo(1);
    const day = localDateOf(started, 'Asia/Kolkata');
    await sql`insert into body_metrics (user_id, measured_on, weight_kg, source) values
      (${u.id}, ${addDays(day, -10)}, 80, 'manual'), (${u.id}, ${addDays(day, -1)}, 72, 'manual')`;
    const run = (await call(u, 'POST', '/running/runs', outdoor('easy-loop', started))).json<RunDetail>();
    const f = fixture('easy-loop');
    expect(run.calories).toBe(summarizeTrack(decodeTrack(f.track), f.durationSeconds, 72).calories);
    expect(run.calories).toBe(f.expected.calories);
  });

  it('a treadmill run: the typed distance, no track, no splits', async () => {
    const u = await user();
    const started = hoursAgo(3);
    const res = await call(u, 'POST', '/running/runs', {
      clientRunId: randomUUID(),
      kind: 'treadmill',
      name: 'Treadmill run',
      startedAt: started.toISOString(),
      endedAt: new Date(started.getTime() + 1600_000).toISOString(),
      durationSeconds: 1500,
      goal: { kind: 'time', value: 1500 },
      distanceM: 5000,
    });
    expect(res.statusCode).toBe(201);
    expect(res.json()).toMatchObject({ kind: 'treadmill', distanceM: 5000, avgPaceSecPerKm: 300, track: null, splitsKm: [], outline: [] });
  });

  it('a track that does not decode is refused with its reason; nothing is kept', async () => {
    const u = await user();
    const req = outdoor('easy-loop', hoursAgo(1));
    const res = await call(u, 'POST', '/running/runs', { ...req, track: { ...req.track!, points: req.track!.points.slice(0, -3) } });
    expect(res.statusCode).toBe(422);
    expect(res.json().error.details[0].path).toBe('track');
    const [count] = await sql<{ n: number }[]>`select count(*)::int as n from runs where user_id = ${u.id}`;
    expect(count!.n).toBe(0);
    // And an outdoor run without a track never reaches the service.
    const noTrack: Partial<CreateRunRequest> = { ...req };
    delete noTrack.track;
    expect((await call(u, 'POST', '/running/runs', noTrack)).statusCode).toBe(422);
  });

  it('the history: newest first, a page at a time, with this week and this month', async () => {
    const u = await user('Asia/Kolkata');
    const today = localDateOf(new Date(), 'Asia/Kolkata');
    // Runs at local noon today and on earlier days, plus one 40 days ago.
    const atNoon = (date: string) => new Date(`${date}T06:30:00.000Z`);
    const days = [0, 1, 2, 3, 40].map((d) => addDays(today, -d));
    const made: string[] = [];
    for (const d of days) {
      const req = outdoor('no-elevation', atNoon(d));
      made.push(req.clientRunId);
      expect((await call(u, 'POST', '/running/runs', req)).statusCode).toBe(201);
    }
    const first = runListSchema.parse((await call(u, 'GET', '/running/runs?limit=2')).json());
    expect(first.runs.map((r) => r.id)).toEqual(made.slice(0, 2));
    expect(first.nextBefore).toBe(first.runs[1]!.startedAt);
    const rest = (await call(u, 'GET', `/running/runs?before=${encodeURIComponent(first.nextBefore!)}`)).json<RunList>();
    expect(rest.runs.map((r) => r.id)).toEqual(made.slice(2));
    expect(rest.nextBefore).toBeNull();

    const one = fixture('no-elevation').expected.distanceM;
    const dow = new Date(`${today}T00:00:00Z`).getUTCDay() || 7;
    const inWeek = days.filter((d) => d >= addDays(today, 1 - dow)).length;
    const inMonth = days.filter((d) => d.slice(0, 7) === today.slice(0, 7)).length;
    expect(first.totals.week.runs).toBe(inWeek);
    expect(first.totals.week.distanceM).toBeCloseTo(one * inWeek, 1);
    expect(first.totals.week.durationSeconds).toBe(fixture('no-elevation').durationSeconds * inWeek);
    expect(first.totals.month.runs).toBe(inMonth);
  });

  it('edits the runner’s own words; deletes a run, track and all', async () => {
    const u = await user();
    const req = outdoor('intervals-with-pauses', hoursAgo(5), { effort: 8 });
    await call(u, 'POST', '/running/runs', req);
    const edited = await call(u, 'PATCH', `/running/runs/${req.clientRunId}`, { name: 'Track reps', note: '3 × 2 min', effort: null });
    expect(edited.statusCode).toBe(200);
    expect(edited.json()).toMatchObject({ name: 'Track reps', note: '3 × 2 min', effort: null });
    expect((await call(u, 'PATCH', `/running/runs/${req.clientRunId}`, { note: '' })).json().note).toBeNull();
    expect((await call(u, 'PATCH', `/running/runs/${req.clientRunId}`, {})).statusCode).toBe(422);

    // Someone else cannot see, change or delete it.
    const other = await user();
    expect((await call(other, 'GET', `/running/runs/${req.clientRunId}`)).statusCode).toBe(404);
    expect((await call(other, 'PATCH', `/running/runs/${req.clientRunId}`, { name: 'Mine now' })).statusCode).toBe(404);
    expect((await call(other, 'DELETE', `/running/runs/${req.clientRunId}`)).statusCode).toBe(404);
    expect((await call(other, 'GET', '/running/runs')).json<RunList>().runs).toEqual([]);

    expect((await call(u, 'DELETE', `/running/runs/${req.clientRunId}`)).statusCode).toBe(204);
    expect((await call(u, 'GET', `/running/runs/${req.clientRunId}`)).statusCode).toBe(404);
    expect((await call(u, 'DELETE', `/running/runs/${req.clientRunId}`)).statusCode).toBe(404);
    const [left] = await sql<{ n: number }[]>`select count(*)::int as n from runs where client_run_id = ${req.clientRunId}`;
    expect(left!.n).toBe(0);
  });

  it('the admin’s switch stops new runs and edits; the history and deleting still work', async () => {
    const u = await user();
    const kept = outdoor('no-elevation', hoursAgo(6));
    await call(u, 'POST', '/running/runs', kept);
    await sql`insert into feature_flags (key, enabled) values ('running', false)`;
    app.features.invalidate();
    try {
      const refused = await call(u, 'POST', '/running/runs', outdoor('no-elevation', hoursAgo(1)));
      expect(refused.statusCode).toBe(403);
      expect(refused.json().error.details[0].issue).toBe('feature-off');
      expect((await call(u, 'PATCH', `/running/runs/${kept.clientRunId}`, { name: 'x' })).statusCode).toBe(403);
      expect((await call(u, 'GET', '/running/runs')).json<RunList>().runs).toHaveLength(1);
      expect((await call(u, 'DELETE', `/running/runs/${kept.clientRunId}`)).statusCode).toBe(204);
    } finally {
      await sql`delete from feature_flags where key = 'running'`;
      app.features.invalidate();
    }
  });

  it('runs go with the account and are in the data export', async () => {
    const u = await user();
    const req = outdoor('no-elevation', hoursAgo(1));
    await call(u, 'POST', '/running/runs', req);
    const exported = (await call(u, 'POST', '/user/export', {})).json();
    const rows = exported.tables.runs as { client_run_id: string; track_points: string }[];
    expect(rows.map((r) => r.client_run_id)).toEqual([req.clientRunId]);
    expect(rows[0]!.track_points).toBe(req.track!.points);
    await sql`delete from users where id = ${u.id}`;
    const [left] = await sql<{ n: number }[]>`select count(*)::int as n from runs where client_run_id = ${req.clientRunId}`;
    expect(left!.n).toBe(0);
  });
});
