/**
 * Phase 18 (§31): the API holds p95 < 500 ms at 50 requests a second.
 *
 *   pnpm --filter @fitos/api load:test        (LOAD_RPS, LOAD_SECONDS, LOAD_USERS)
 *
 * Runs on the isolated `<db>_test` database (never the developer's), with the
 * real app listening on a loopback port and real HTTP requests: migrations,
 * the exercise, food and mess seeds, the mess mirror fed the captured MessIT
 * fixtures, then LOAD_USERS onboarded users, each with a generated programme,
 * a mess and one completed session. The load is open-loop — a request every
 * 1/RPS seconds whatever the previous one is doing — across the screens the
 * app opens most, spread over the users so the real per-user rate limit
 * (120/min) stays switched on. Exit 1 when p95 ≥ LOAD_P95_MS, when any
 * request fails, or when the rate actually sent falls short.
 *
 * The client shares the process with the server, so the numbers include the
 * client's own overhead: they are an upper bound for the server.
 */
import { randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { performance } from 'node:perf_hooks';

import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, type Program, type WorkoutSession } from '@fitos/contracts';

import { createDatabase } from '../db/client.js';
import { seedFoods } from '../db/food-seed/load.js';
import { migrateUp } from '../db/migrate.js';
import { seedExercises } from '../db/seed.js';
import { seedMesses } from '../db/seed-mess.js';
import { runMirror, type FetchOutcome } from '../modules/mess/mirror.js';
import { buildDbApp } from '../test/build-test-app.js';
import { ensureTestDatabase, loadDotEnv, resolveTestDatabaseUrl } from '../test/test-database.js';

const RPS = Number(process.env['LOAD_RPS'] ?? 50);
const SECONDS = Number(process.env['LOAD_SECONDS'] ?? 60);
const WARMUP_SECONDS = 5;
const USERS = Number(process.env['LOAD_USERS'] ?? 30);
const P95_MS = Number(process.env['LOAD_P95_MS'] ?? 500);

/** What the app opens, weighted by how often (TODAY on every launch, the tabs after it). */
const MIX: readonly (readonly [string, number])[] = [
  ['/v1/today', 4],
  ['/v1/training/today', 2],
  ['/v1/nutrition/today', 2],
  ['/v1/mess/menu', 2],
  ['/v1/progress/summary', 1],
  ['/v1/recovery/today', 1],
  ['/v1/training/volume', 1],
  ['/v1/nutrition/foods/search?q=paneer', 1],
  ['/v1/exercises', 1],
  ['/v1/user/profile', 1],
];

const FIXTURES = new URL('../../../../packages/core/test/fixtures/messit-2026-09-24/', import.meta.url);

function percentile(sorted: readonly number[], p: number): number {
  if (sorted.length === 0) return Number.NaN;
  return sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)]!;
}

const sleep = (ms: number): Promise<void> => new Promise((r) => setTimeout(r, Math.max(0, ms)));

async function main(): Promise<void> {
  loadDotEnv();
  const url = resolveTestDatabaseUrl();
  if (url === undefined) throw new Error('DATABASE_URL is not set: the load test runs on its `_test` database.');
  await ensureTestDatabase(url);

  console.log('setting up: migrations, seeds, mess mirror');
  await migrateUp(url);
  await seedExercises(url);
  await seedFoods(url);
  const handle = createDatabase(url);
  await seedMesses(handle.db);
  await runMirror(handle, {
    fetcher: async (u): Promise<FetchOutcome> => {
      const name = /(hostel-\d-mess-\d)\.json$/.exec(u)?.[1];
      return name === undefined ? { ok: false } : { ok: true, body: readFileSync(fileURLToPath(new URL(`${name}.json`, FIXTURES)), 'utf8') };
    },
  });

  const sql = postgres(url, { max: 1 });
  await sql`delete from users where firebase_uid like 'load-%'`;
  const { app, verifier } = await buildDbApp(url, { TRUST_PROXY: 'loopback' });
  await app.listen({ port: 0, host: '127.0.0.1' });
  const address = app.server.address();
  if (address === null || typeof address === 'string') throw new Error('no port');
  const base = `http://127.0.0.1:${address.port}`;

  interface U { token: string; ip: string }
  const headers = (u: U): Record<string, string> => ({ authorization: `Bearer ${u.token}`, 'x-forwarded-for': u.ip, 'content-type': 'application/json' });
  async function call(u: U, method: string, path: string, body?: unknown): Promise<Response> {
    const init: RequestInit = { method, headers: headers(u) };
    if (body !== undefined) init.body = JSON.stringify(body);
    const r = await fetch(`${base}${path}`, init);
    if (r.status >= 300) throw new Error(`${method} ${path} → ${r.status}: ${await r.text()}`);
    return r;
  }

  console.log(`setting up: ${USERS} users (onboarded, programme, mess, one session)`);
  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };
  const users: U[] = [];
  for (let i = 0; i < USERS; i++) {
    const u = { token: `load-tok-${i}`, ip: `198.18.${Math.floor(i / 250)}.${(i % 250) + 1}` };
    verifier.accept(u.token, { uid: `load-uid-${i}`, email: `load${i}@vit.ac.in` });
    await call(u, 'POST', '/v1/auth/session', {});
    for (const step of [
      { step: 'goal', goalType: i % 2 === 0 ? 'muscle-gain' : 'fat-loss' },
      { step: 'about', displayName: `Load ${i}`, sex: i % 2 === 0 ? 'male' : 'female', birthDate: '2004-06-01', heightCm: 170, weightKg: 68, consent },
      { step: 'experience', experienceLevel: 'intermediate', trainingDaysPerWeek: 4, activityLevel: 'light' },
      { step: 'training', trainingLocation: 'campus-gym', equipment: ['barbell', 'dumbbell', 'machine', 'cable'] },
      { step: 'food', dietType: i % 3 === 0 ? 'non-vegetarian' : 'vegetarian', allergies: [] },
    ]) await call(u, 'POST', '/v1/onboarding/answer', step);
    await call(u, 'POST', '/v1/onboarding/complete', {});
    const program = (await (await call(u, 'POST', '/v1/training/program/generate', {})).json()) as Program;
    await call(u, 'PATCH', '/v1/user/profile', { isVitStudent: true, mess: { providerId: 'vit-vellore', hostelId: i % 2 === 0 ? 'mens' : 'womens', messId: 'veg' } });
    const day = program.days.find((d) => !d.isRest)!;
    const startedAt = new Date(Date.now() - 2 * 86_400_000).toISOString();
    const s = (await (await call(u, 'POST', '/v1/training/sessions', { clientSessionId: randomUUID(), programDayId: day.id, startedAt })).json()) as WorkoutSession;
    const ex = s.exercises[0]!;
    await call(u, 'POST', `/v1/training/sessions/${s.id}/sets`, {
      sets: ex.targets.map((t) => ({ clientSetId: randomUUID(), sessionExerciseId: ex.id, setIndex: t.setIndex, weightKg: 60, reps: t.repsMax, rir: 2, loggedAt: startedAt })),
    });
    await call(u, 'POST', `/v1/training/sessions/${s.id}/complete`, { completedAt: new Date(Date.parse(startedAt) + 50 * 60_000).toISOString() });
    users.push(u);
  }

  const paths = MIX.flatMap(([p, w]) => Array.from({ length: w }, () => p));
  const results: { path: string; ms: number; status: number }[] = [];
  const inFlight: Promise<void>[] = [];
  const total = (SECONDS + WARMUP_SECONDS) * RPS;
  console.log(`load: ${RPS} rps for ${SECONDS} s after a ${WARMUP_SECONDS} s warm-up (${total} requests)`);
  const start = performance.now();
  for (let i = 0; i < total; i++) {
    await sleep(start + (i * 1000) / RPS - performance.now());
    const path = paths[i % paths.length]!;
    const u = users[i % users.length]!;
    const counted = i >= WARMUP_SECONDS * RPS;
    const t0 = performance.now();
    inFlight.push(
      fetch(`${base}${path}`, { headers: headers(u) })
        .then(async (r) => {
          await r.arrayBuffer();
          if (counted) results.push({ path, ms: performance.now() - t0, status: r.status });
        })
        .catch(() => {
          if (counted) results.push({ path, ms: performance.now() - t0, status: 0 });
        }),
    );
  }
  const sentSeconds = (performance.now() - start) / 1000;
  await Promise.all(inFlight);

  const summary = (rows: typeof results) => {
    const ms = rows.map((r) => r.ms).sort((a, b) => a - b);
    return { n: rows.length, p50: percentile(ms, 50), p95: percentile(ms, 95), p99: percentile(ms, 99), max: ms.at(-1) ?? Number.NaN, failed: rows.filter((r) => r.status < 200 || r.status >= 300).length };
  };
  const f = (x: number): string => x.toFixed(1).padStart(7);
  console.log(`\n${'endpoint'.padEnd(40)}      n     p50     p95     p99     max  failed`);
  for (const [path] of MIX) {
    const s = summary(results.filter((r) => r.path === path));
    console.log(`${path.padEnd(40)} ${String(s.n).padStart(6)} ${f(s.p50)} ${f(s.p95)} ${f(s.p99)} ${f(s.max)} ${String(s.failed).padStart(7)}`);
  }
  const all = summary(results);
  console.log(`${'ALL'.padEnd(40)} ${String(all.n).padStart(6)} ${f(all.p50)} ${f(all.p95)} ${f(all.p99)} ${f(all.max)} ${String(all.failed).padStart(7)}`);
  const achieved = total / sentSeconds;
  console.log(`\nsent ${total} requests in ${sentSeconds.toFixed(1)} s = ${achieved.toFixed(1)} rps (target ${RPS})`);
  for (const r of results.filter((x) => x.status < 200 || x.status >= 300).slice(0, 5)) console.log(`failed: ${r.path} → ${r.status}`);

  await sql`delete from users where firebase_uid like 'load-%'`;
  await app.close();
  await handle.client.end({ timeout: 5 });
  await sql.end({ timeout: 5 });

  const ok = all.p95 < P95_MS && all.failed === 0 && achieved >= RPS * 0.95;
  console.log(ok ? `PASS: p95 ${all.p95.toFixed(1)} ms < ${P95_MS} ms at ${RPS} rps` : `FAIL: p95 ${all.p95.toFixed(1)} ms, ${all.failed} failed, ${achieved.toFixed(1)} rps`);
  process.exitCode = ok ? 0 : 1;
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
