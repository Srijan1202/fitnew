/**
 * /v1/progress on real Postgres (Phase 12, ADR-018): the summary computed on
 * read, weight and measurement upserts, and every rule the owner approved —
 * the stored timezone, 30 days back and never ahead, no target recalculation
 * from a Progress weight, and the reading still counting as TODAY's
 * log-weight evidence.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { progressSummarySchema, type ProgressSummary } from '@fitos/contracts';
import { addDays, localDateOf } from '@fitos/core/nutrition/log';
import { summariseTrend } from '@fitos/core/nutrition/trend';

import { migrateUp } from '../../db/migrate.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

/** A fixed-offset zone whose local hour is `hour` right now (as the TODAY suite does). */
function zoneAt(hour: number): string {
  let o = hour - new Date().getUTCHours();
  if (o > 14) o -= 24;
  if (o < -12) o += 24;
  return o === 0 ? 'Etc/GMT' : o > 0 ? `Etc/GMT-${o}` : `Etc/GMT+${-o}`;
}

describeIfDb('/v1/progress (real Postgres)', { timeout: 60_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'pr-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
    tz: string;
  }
  const ipOf = new Map<string, string>();
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': ipOf.get(token) ?? '203.0.160.250' });

  async function user(tz = 'Asia/Kolkata'): Promise<U> {
    n += 1;
    const token = `pr-tok-${n}`;
    ipOf.set(token, `203.0.${160 + Math.floor(n / 250)}.${n % 250}`);
    verifier.accept(token, { uid: `pr-uid-${n}`, email: `pr${n}@vit.ac.in` });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`pr-uid-${n}`}`;
    await sql`update users set timezone = ${tz} where id = ${row!.id}`;
    return { token, id: row!.id, tz };
  }

  const today = (u: U) => localDateOf(new Date(), u.tz);
  const summary = async (u: U, window?: string): Promise<ProgressSummary> => {
    const r = await app.inject({ method: 'GET', url: `/v1/progress/summary${window === undefined ? '' : `?window=${window}`}`, headers: auth(u.token) });
    expect(r.statusCode, r.body).toBe(200);
    return progressSummarySchema.parse(r.json());
  };
  const weigh = (u: U, body: Record<string, unknown>) => app.inject({ method: 'POST', url: '/v1/progress/weight', headers: auth(u.token), payload: body });
  const measure = (u: U, body: Record<string, unknown>) => app.inject({ method: 'POST', url: '/v1/progress/measurement', headers: auth(u.token), payload: body });
  const issue = (r: { json: () => unknown }) => (r.json() as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;

  async function seedWeights(u: U, days: number, kg: (i: number) => number): Promise<void> {
    for (let i = days - 1; i >= 0; i--) {
      await sql`insert into body_metrics (user_id, measured_on, weight_kg, source) values (${u.id}, ${addDays(today(u), -i)}, ${kg(days - 1 - i)}, 'manual')
        on conflict (user_id, measured_on) do update set weight_kg = excluded.weight_kg, deleted_at = null`;
    }
  }

  async function targetsRow(u: U, kcal = 2400, protein = 140, from = '2026-01-01'): Promise<void> {
    await sql`
      insert into nutrition_targets (user_id, effective_from, kcal, protein_g, carb_g, fat_g, fiber_g, bmr, tdee_estimate, rationale, reason)
      values (${u.id}, ${from}, ${kcal}, ${protein}, 290, 70, 30, 1700, 2500, ${sql.json(['test'])}, 'onboarding')`;
  }

  /* ------------------------------------------------------------ access -- */

  it('401 without a session on all three endpoints', async () => {
    expect((await app.inject({ method: 'GET', url: '/v1/progress/summary' })).statusCode).toBe(401);
    expect((await app.inject({ method: 'POST', url: '/v1/progress/weight', payload: { weightKg: 70 } })).statusCode).toBe(401);
    expect((await app.inject({ method: 'POST', url: '/v1/progress/measurement', payload: { site: 'waist', valueCm: 80 } })).statusCode).toBe(401);
  });

  it('empty history: a valid summary with nothing invented', async () => {
    const u = await user();
    const s = await summary(u);
    expect(s).toMatchObject({ window: '30d', today: today(u), from: addDays(today(u), -29) });
    expect(s.weight).toEqual({ points: [], currentTrendKg: null, weeklyChangeKg: null, daysOfData: 0, isReliable: false, windowChangeKg: null, windowChangeDays: null });
    expect(s.measurements).toEqual([]);
    expect(s.prs).toEqual([]);
    expect(s.bestLifts).toEqual([]);
    expect(s.adherence).toEqual({ protein: { met: 0, of: 0, percent: null }, calories: { met: 0, of: 0, percent: null }, loggedDays: 0, daysWithoutTarget: 0 });
    expect(s.consistency.planned).toBeNull();
    expect(s.consistency.completed).toBe(0);
  });

  it('isolation: one user never sees another\'s readings, and writes land only on the caller', async () => {
    const a = await user();
    const b = await user();
    expect((await weigh(a, { weightKg: 71.2 })).statusCode).toBe(201);
    expect((await measure(a, { site: 'waist', valueCm: 82 })).statusCode).toBe(201);
    const sb = await summary(b);
    expect(sb.weight.points).toEqual([]);
    expect(sb.measurements).toEqual([]);
    expect((await summary(a)).weight.points).toHaveLength(1);
    const [rows] = await sql<{ n: number }[]>`select count(*)::int as n from body_metrics where user_id = ${b.id}`;
    expect(rows!.n).toBe(0);
  });

  /* ------------------------------------------------------------- weight -- */

  it('weight: 201 for a new day, 200 when it replaces the day (one row); the trend follows; targets never recalculated', async () => {
    const u = await user();
    await targetsRow(u);
    const first = await weigh(u, { weightKg: 72.4 });
    expect(first.statusCode, first.body).toBe(201);
    expect(first.json()).toEqual({ weight: { date: today(u), weightKg: 72.4, source: 'manual' } });
    const again = await weigh(u, { weightKg: 72.0 });
    expect(again.statusCode).toBe(200);
    const rows = await sql<{ w: string }[]>`select weight_kg as w from body_metrics where user_id = ${u.id}`;
    expect(rows).toEqual([{ w: '72.00' }]);
    expect((await summary(u)).weight.points).toEqual([{ date: today(u), rawKg: 72, trendKg: 72 }]);
    // Owner D5: no silent target change from a Progress weight.
    const t = await sql<{ n: number }[]>`select count(*)::int as n from nutrition_targets where user_id = ${u.id}`;
    expect(t[0]!.n).toBe(1);
    // A deleted day comes back on the next write, as a new reading (201).
    await sql`update body_metrics set deleted_at = now() where user_id = ${u.id}`;
    expect((await summary(u)).weight.points).toEqual([]);
    expect((await weigh(u, { weightKg: 71.5 })).statusCode).toBe(201);
  });

  it('dates: up to 30 days back, never ahead, a real calendar date; ranges enforced', async () => {
    const u = await user();
    const t = today(u);
    expect((await weigh(u, { weightKg: 70, date: addDays(t, -30) })).statusCode).toBe(201);
    const tooOld = await weigh(u, { weightKg: 70, date: addDays(t, -31) });
    expect(tooOld.statusCode).toBe(422);
    expect(issue(tooOld)).toBe('more than 30 days ago');
    const future = await weigh(u, { weightKg: 70, date: addDays(t, 1) });
    expect(future.statusCode).toBe(422);
    expect(issue(future)).toBe('in the future');
    expect(issue(await weigh(u, { weightKg: 70, date: '2026-02-30' }))).toBe('not a date');
    expect((await weigh(u, { weightKg: 12 })).statusCode).toBe(422);
    expect((await weigh(u, { weightKg: 70, source: 'health-sync' })).statusCode).toBe(422);
    expect((await measure(u, { site: 'neck', valueCm: 40 })).statusCode).toBe(422);
    expect((await measure(u, { site: 'arm', valueCm: 300 })).statusCode).toBe(422);
    expect((await measure(u, { site: 'arm', valueCm: 35, date: addDays(t, 1) })).statusCode).toBe(422);
  });

  it('timezone: "today" is the stored zone\'s date, not UTC — two users on either side of the date line', async () => {
    const east = await user('Etc/GMT-14');
    const west = await user('Etc/GMT+12');
    const e = (await weigh(east, { weightKg: 70 })).json() as { weight: { date: string } };
    const w = (await weigh(west, { weightKg: 70 })).json() as { weight: { date: string } };
    expect(e.weight.date).toBe(localDateOf(new Date(), 'Etc/GMT-14'));
    expect(w.weight.date).toBe(localDateOf(new Date(), 'Etc/GMT+12'));
    expect(e.weight.date).not.toBe(w.weight.date);
    // East may log its "today", which is west's tomorrow: west cannot.
    expect((await weigh(west, { weightKg: 70, date: e.weight.date })).statusCode).toBe(422);
  });

  it('trend: the 10-day gate, the ≥7-day window change, and the EWMA equal to core over the stored readings', async () => {
    const u = await user();
    const noise = [0.9, -1.1, 0.4, -0.6, 1.2, -0.8, 0.3, -1.0, 0.7, -0.2];
    await seedWeights(u, 9, (i) => 80 + noise[i]!);
    let s = await summary(u);
    expect(s.weight.daysOfData).toBe(9);
    expect(s.weight.isReliable).toBe(false);
    expect(s.weight.weeklyChangeKg).toBeNull();
    expect(s.weight.windowChangeDays).toBe(8);
    await seedWeights(u, 30, (i) => 80 + noise[i % 10]! - i * 0.05);
    s = await summary(u);
    expect(s.weight.isReliable).toBe(true);
    expect(s.weight.weeklyChangeKg).not.toBeNull();
    expect(s.weight.points).toHaveLength(30);
    const stored = await sql<{ d: string; w: string }[]>`select measured_on as d, weight_kg as w from body_metrics where user_id = ${u.id} and deleted_at is null`;
    const core = summariseTrend(stored.map((r) => ({ date: r.d, kg: Number(r.w) })));
    expect(s.weight.currentTrendKg).toBe(core.currentTrendKg);
    expect(s.weight.weeklyChangeKg).toBe(core.weeklyChangeKg);
    // One reading in the window → no change figure (never day-over-day).
    const lone = await user();
    await seedWeights(lone, 1, () => 70);
    expect((await summary(lone)).weight.windowChangeKg).toBeNull();
  });

  it('windows: 30d and 90d cut the same whole-history trend; a year of readings stays fast', async () => {
    const u = await user();
    await seedWeights(u, 365, (i) => 85 - i * 0.02 + ((i * 7) % 5) * 0.2);
    const s30 = await summary(u, '30d');
    const s90 = await summary(u, '90d');
    expect(s30.weight.points).toHaveLength(30);
    expect(s90.weight.points).toHaveLength(90);
    expect(s90.from).toBe(addDays(today(u), -89));
    // The same trend value on the same day in both windows (smoothed over the whole history).
    expect(s30.weight.points[0]).toEqual(s90.weight.points.find((p) => p.date === s30.weight.points[0]!.date));
    expect((await app.inject({ method: 'GET', url: '/v1/progress/summary?window=7d', headers: auth(u.token) })).statusCode).toBe(422);
  });

  /* ------------------------------------------------------- measurements -- */

  it('measurements: one per day and site (201 then 200), latest per site, change only across ≥ 7 days', async () => {
    const u = await user();
    const t = today(u);
    expect((await measure(u, { site: 'waist', valueCm: 86, date: addDays(t, -20) })).statusCode).toBe(201);
    expect((await measure(u, { site: 'waist', valueCm: 84.6 })).statusCode).toBe(201);
    const fix = await measure(u, { site: 'waist', valueCm: 84.5 });
    expect(fix.statusCode).toBe(200);
    expect(fix.json()).toEqual({ measurement: { date: t, site: 'waist', valueCm: 84.5 } });
    expect((await measure(u, { site: 'arm', valueCm: 35, date: addDays(t, -3) })).statusCode).toBe(201);
    expect((await measure(u, { site: 'arm', valueCm: 35.5 })).statusCode).toBe(201);
    const s = await summary(u);
    expect(s.measurements).toEqual([
      { site: 'waist', latest: { date: t, valueCm: 84.5 }, changeCm: -1.5, changeDays: 20 },
      { site: 'arm', latest: { date: t, valueCm: 35.5 }, changeCm: null, changeDays: null },
    ]);
    const rows = await sql<{ n: number }[]>`select count(*)::int as n from body_measurements where user_id = ${u.id} and site = 'waist'`;
    expect(rows[0]!.n).toBe(2);
    // Soft-deleted readings are excluded.
    await sql`update body_measurements set deleted_at = now() where user_id = ${u.id} and site = 'arm'`;
    expect((await summary(u)).measurements.map((m) => m.site)).toEqual(['waist']);
  });

  /* ---------------------------------------------- adherence & training -- */

  it('adherence: logged days only, protein at the high end, kcal overlapping ±10 %, a target change mid-window', async () => {
    const u = await user();
    const t = today(u);
    await targetsRow(u, 2000, 100);
    await targetsRow(u, 2500, 150, addDays(t, -2));
    const day = (d: string, kLo: number, kHi: number, pHi: number, items = 2) =>
      sql`insert into daily_nutrition (user_id, local_date, kcal_low, kcal_high, protein_low, protein_high, item_count) values (${u.id}, ${d}, ${kLo}, ${kHi}, 0, ${pHi}, ${items})`;
    await day(addDays(t, -5), 1700, 1850, 100);
    await day(addDays(t, -4), 1500, 1790, 99);
    await day(addDays(t, -3), 0, 0, 0, 0);
    await day(addDays(t, -1), 2700, 2900, 120);
    await day(t, 2760, 2900, 160);
    await day(addDays(t, -40), 2000, 2000, 200); // outside the window
    const s = await summary(u);
    expect(s.adherence).toEqual({ protein: { met: 2, of: 4, percent: 50 }, calories: { met: 2, of: 4, percent: 50 }, loggedDays: 4, daysWithoutTarget: 0 });
  });

  it('training: consistency against the active programme\'s days; records and best Epley 1RM from the window', async () => {
    const u = await user();
    const t = today(u);
    const [program] = await sql<{ id: string }[]>`
      insert into programs (user_id, name, split_type, days_per_week, source) values (${u.id}, 'P', 'full-body', 3, 'generated') returning id`;
    for (const [dow, rest] of [[1, false], [3, false], [5, false], [7, true]] as const) {
      await sql`insert into program_days (program_id, day_of_week, session_name, is_rest) values (${program!.id}, ${dow}, ${`D${dow}`}, ${rest})`;
    }
    const [ex] = await sql<{ id: string; name: string }[]>`
      insert into exercises (slug, name, movement_pattern, equipment, difficulty, default_increment_kg, instructions)
      values (${`pr-bench-${n}`}, ${`Bench ${n}`}, 'horizontal-push', '{barbell}', 'beginner', 2.5, '{"a"}') returning id, name`;
    const session = async (localDay: string, sets: [number, number][]) => {
      const completedAt = new Date(Date.parse(`${localDay}T12:00:00Z`));
      const [s] = await sql<{ id: string }[]>`
        insert into workout_sessions (user_id, client_session_id, status, name, started_at, completed_at, duration_seconds)
        values (${u.id}, ${randomUUID()}, 'completed', 'S', ${new Date(completedAt.getTime() - 3_600_000)}, ${completedAt}, 3600) returning id`;
      const [se] = await sql<{ id: string }[]>`
        insert into session_exercises (session_id, exercise_id, order_index, client_exercise_id) values (${s!.id}, ${ex!.id}, 0, ${randomUUID()}) returning id`;
      for (const [i, [w, r]] of sets.entries()) {
        await sql`insert into set_logs (session_exercise_id, set_index, set_type, weight_kg, reps, rir, logged_at, client_set_id)
          values (${se!.id}, ${i + 1}, 'working', ${w}, ${r}, 2, ${completedAt}, ${randomUUID()})`;
      }
      return s!.id;
    };
    await session(addDays(t, -40), [[100, 5]]); // outside the window
    await session(addDays(t, -2), [[80, 5], [85, 3]]);
    await session(t, [[82.5, 4]]);
    const [set] = await sql<{ id: string }[]>`select id from set_logs order by logged_at desc limit 1`;
    await sql`insert into exercise_prs (user_id, exercise_id, pr_type, value, previous, reason, achieved_at, set_log_id)
      values (${u.id}, ${ex!.id}, 'weight', 85, 80, '85 kg beats your best of 80 kg.', ${new Date(Date.parse(`${addDays(t, -2)}T12:00:00Z`))}, ${set!.id})`;
    const s = await summary(u);
    expect(s.consistency.completed).toBe(2);
    expect(s.consistency.planned).not.toBeNull();
    expect(s.consistency.weeks.reduce((a, w) => a + w.completed, 0)).toBe(2);
    expect(s.bestLifts).toEqual([{ exerciseId: ex!.id, exerciseName: ex!.name, estimated1RmKg: 93.5, weightKg: 85, reps: 3, date: addDays(t, -2) }]);
    expect(s.prs.map((p) => [p.prType, p.value, p.previous, p.achievedOn])).toEqual([['weight', 85, 80, addDays(t, -2)]]);
    // Deleted sessions do not count.
    await sql`update workout_sessions set deleted_at = now() where user_id = ${u.id}`;
    const after = await summary(u);
    expect(after.consistency.completed).toBe(0);
    expect(after.bestLifts).toEqual([]);
    await sql`delete from exercise_prs where user_id = ${u.id}`;
    await sql`delete from users where id = ${u.id}`;
    await sql`delete from exercises where id = ${ex!.id}`;
  });

  /* ------------------------------------------------- TODAY interaction -- */

  it('a Progress weight is TODAY\'s log-weight evidence (the Phase 11 flow is unchanged)', async () => {
    const u = await user(zoneAt(12));
    const plan = (await app.inject({ method: 'GET', url: '/v1/today', headers: auth(u.token) })).json() as { actions: { id: string; kind: string }[] };
    const weight = plan.actions.find((a) => a.kind === 'log-weight')!;
    const ev = (event: string) =>
      app.inject({ method: 'POST', url: `/v1/today/actions/${weight.id}/event`, headers: auth(u.token), payload: { clientEventId: randomUUID(), event, occurredAt: new Date().toISOString() } });
    expect((await ev('shown')).statusCode).toBe(201);
    expect((await ev('accepted')).statusCode).toBe(201);
    expect((await ev('completed')).statusCode).toBe(422);
    expect((await weigh(u, { weightKg: 70.3 })).statusCode).toBe(201);
    expect((await ev('completed')).statusCode).toBe(201);
  });

  /* ------------------------------------------------------ performance -- */

  it('p95 of GET /progress/summary under 300 ms with a year of weights, 90 days of food and training', async () => {
    const u = await user();
    await seedWeights(u, 365, (i) => 80 + ((i * 3) % 7) * 0.1);
    await targetsRow(u);
    for (let i = 0; i < 90; i++) {
      await sql`insert into daily_nutrition (user_id, local_date, kcal_low, kcal_high, protein_low, protein_high, item_count) values (${u.id}, ${addDays(today(u), -i)}, 2000, 2400, 100, 130, 3)`;
    }
    await summary(u, '90d'); // warm
    const times: number[] = [];
    for (let i = 0; i < 40; i++) {
      const t0 = performance.now();
      const r = await app.inject({ method: 'GET', url: '/v1/progress/summary?window=90d', headers: auth(u.token) });
      times.push(performance.now() - t0);
      expect(r.statusCode).toBe(200);
    }
    times.sort((a, b) => a - b);
    const p95 = times[Math.ceil(0.95 * times.length) - 1]!;
    console.info(`GET /v1/progress/summary p50 ${times[Math.floor(times.length / 2)]!.toFixed(1)} ms, p95 ${p95.toFixed(1)} ms (n=${times.length})`);
    expect(p95).toBeLessThan(300);
  });
});
