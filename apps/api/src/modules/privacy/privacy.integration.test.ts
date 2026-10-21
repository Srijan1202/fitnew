/**
 * Phase 17 (ADR-023) on real Postgres: consent per purpose (FITOS AI is its
 * own, revocable), the export is complete and machine-readable, deletion
 * leaves no residue — checked by searching every column of every table for
 * the user's id, email and Firebase uid — and the limits hold.
 */
import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, exportResponseSchema, type Program, type WorkoutSession } from '@fitos/contracts';

import { buildApp } from '../../app.js';
import { createDatabase } from '../../db/client.js';
import { migrateUp } from '../../db/migrate.js';
import { seedExercises } from '../../db/seed.js';
import { RecordingAccountDeleter } from '../../lib/account-deleter.js';
import { databaseUrl, testEnv } from '../../test/build-test-app.js';
import { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { EXPORT_PER_HOUR } from './routes.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/user privacy (real Postgres)', { timeout: 90_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildApp>>;
  const verifier = new FakeTokenVerifier();
  const deleter = new RecordingAccountDeleter();
  let n = 0;

  beforeAll(async () => {
    await migrateUp(url);
    await seedExercises(url);
    sql = postgres(url, { max: 1 });
    app = await buildApp(testEnv({ DATABASE_URL: url }), { database: createDatabase(url), tokenVerifier: verifier, accountDeleter: deleter });
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'pv-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
    uid: string;
    email: string;
  }
  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `198.30.${n % 250}.${(n * 3) % 250}` });
  const call = (u: U | null, method: 'GET' | 'POST' | 'DELETE', path: string, payload?: unknown) =>
    app.inject({
      method,
      url: `/v1${path}`,
      headers: u === null ? { 'x-forwarded-for': '198.31.0.1' } : headers(u.token),
      ...(payload !== undefined ? { payload: payload as Record<string, unknown> } : {}),
    });
  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };

  async function user(): Promise<U> {
    n += 1;
    const token = `pv-tok-${n}`;
    const uid = `pv-uid-${n}`;
    const email = `pv${n}.someone@vit.ac.in`;
    verifier.accept(token, { uid, email });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${uid}`;
    const u = { token, id: row!.id, uid, email };
    for (const body of [
      { step: 'goal', goalType: 'muscle-gain' },
      { step: 'about', displayName: 'Privacy Person', sex: 'female', birthDate: '2003-02-01', heightCm: 162, weightKg: 58, consent },
      { step: 'experience', experienceLevel: 'beginner', trainingDaysPerWeek: 3, activityLevel: 'light' },
      { step: 'training', trainingLocation: 'commercial-gym', equipment: ['barbell', 'dumbbell', 'machine', 'cable'] },
      { step: 'food', dietType: 'vegetarian', allergies: [] },
    ]) {
      const r = await call(u, 'POST', '/onboarding/answer', body);
      expect(r.statusCode, r.body).toBe(200);
    }
    expect((await call(u, 'POST', '/onboarding/complete', {})).statusCode).toBe(200);
    return u;
  }

  /** Data across the product: a programme, a completed session with sets, food, a check-in, TODAY, reminders, a push token. */
  async function lived(u: U): Promise<void> {
    const program: Program = (await call(u, 'POST', '/training/program/generate', {})).json();
    const day = program.days.find((d) => !d.isRest)!;
    const startedAt = new Date(Date.now() - 3_600_000).toISOString();
    const s: WorkoutSession = (await call(u, 'POST', '/training/sessions', { clientSessionId: randomUUID(), programDayId: day.id, startedAt })).json();
    const x = s.exercises[0]!;
    await call(u, 'POST', `/training/sessions/${s.id}/sets`, {
      sets: x.targets.map((t) => ({ clientSetId: randomUUID(), sessionExerciseId: x.id, setIndex: t.setIndex, weightKg: 30, reps: 10, rir: 2, loggedAt: startedAt })),
    });
    await call(u, 'POST', `/training/sessions/${s.id}/complete`, { completedAt: new Date().toISOString() });
    const log = await call(u, 'POST', '/nutrition/logs', {
      clientLogId: randomUUID(), mealSlot: 'lunch', entryMethod: 'quick-add', quickAdd: { name: 'Rajma chawal at home', kcal: 610, proteinG: 18, carbG: 95, fatG: 14 },
    });
    expect(log.statusCode, log.body).toBe(201);
    expect((await call(u, 'POST', '/recovery/log', { sleepHours: 6.5, soreness: 3, energy: 3 })).statusCode).toBeLessThan(300);
    expect((await call(u, 'GET', '/today')).statusCode).toBe(200);
    expect((await call(u, 'POST', '/notifications/plan', { events: [] })).statusCode).toBe(200);
    expect((await call(u, 'POST', '/notifications/token', { token: `fcm-${u.uid}-${'x'.repeat(20)}`, platform: 'android' })).statusCode).toBe(204);
    expect((await call(u, 'POST', '/user/consents', { type: 'ai-processing', granted: true })).statusCode).toBe(200);
  }

  it('every privacy route is default-deny', async () => {
    for (const [m, p] of [['GET', '/user/consents'], ['POST', '/user/consents'], ['POST', '/user/export'], ['DELETE', '/user']] as const) {
      expect((await call(null, m, p, {})).statusCode, `${m} ${p}`).toBe(401);
    }
  });

  /* ------------------------------------------------------------ consent -- */

  it('§23.1 consent per purpose: the two required ones from onboarding; FITOS AI optional, revocable, and enforced', async () => {
    const u = await user();
    const c = (await call(u, 'GET', '/user/consents')).json() as { needsReconsent: boolean; items: { type: string; granted: boolean; required: boolean; policyVersion: string | null }[] };
    expect(c.needsReconsent).toBe(false);
    expect(c.items.map((i) => [i.type, i.granted, i.required])).toEqual([
      ['privacy-policy', true, true],
      ['health-data-processing', true, true],
      ['ai-processing', false, false],
    ]);

    // Without the AI consent, FITOS AI refuses — before any model call.
    const refused = await call(u, 'POST', '/ai/chat', { message: 'hi' });
    expect(refused.statusCode).toBe(403);
    expect((refused.json() as { error: { details: { issue: string }[] } }).error.details[0]!.issue).toBe('ai-processing');

    const granted = (await call(u, 'POST', '/user/consents', { type: 'ai-processing', granted: true })).json() as { items: { type: string; granted: boolean }[] };
    expect(granted.items.find((i) => i.type === 'ai-processing')!.granted).toBe(true);
    expect((await call(u, 'POST', '/ai/chat', { message: 'hi' })).statusCode).not.toBe(403);
    await call(u, 'POST', '/user/consents', { type: 'ai-processing', granted: false });
    expect((await call(u, 'POST', '/ai/chat', { message: 'hi' })).statusCode).toBe(403);

    // A required purpose cannot be withdrawn here (deleting the account is the way).
    expect((await call(u, 'POST', '/user/consents', { type: 'health-data-processing', granted: false })).statusCode).toBe(422);
    // Every change is a record, with the policy version (none is overwritten).
    const rows = await sql<{ consent_type: string; granted: boolean; policy_version: string }[]>`
      select consent_type::text, granted, policy_version from consent_records where user_id = ${u.id} and consent_type = 'ai-processing' order by granted_at`;
    expect(rows.map((r) => r.granted)).toEqual([true, false]);
    expect(rows.every((r) => r.policy_version === CURRENT_POLICY_VERSION)).toBe(true);
  });

  it('a policy update asks for re-consent; re-granting the required ones to the new version clears it', async () => {
    const u = await user();
    await sql`update consent_records set policy_version = '2026-09-21' where user_id = ${u.id}`;
    expect(((await call(u, 'GET', '/user/consents')).json() as { needsReconsent: boolean }).needsReconsent).toBe(true);
    for (const type of ['privacy-policy', 'health-data-processing']) {
      expect((await call(u, 'POST', '/user/consents', { type, granted: true })).statusCode).toBe(200);
    }
    expect(((await call(u, 'GET', '/user/consents')).json() as { needsReconsent: boolean }).needsReconsent).toBe(false);
  });

  /* ------------------------------------------------------------- export -- */

  it('§23.4 export: complete (every owned row of every table) and machine-readable; nobody else in it', async () => {
    const u = await user();
    const other = await user();
    await lived(u);
    await lived(other);
    const r = await call(u, 'POST', '/user/export', {});
    expect(r.statusCode, r.body).toBe(200);
    expect(r.headers['content-disposition']).toMatch(/attachment; filename="fitos-export-\d{4}-\d{2}-\d{2}\.json"/);
    const file = exportResponseSchema.parse(JSON.parse(r.body));
    expect(file).toMatchObject({ format: 'fitos-export', version: 1, userId: u.id });
    for (const t of ['users', 'user_profiles', 'user_goals', 'consent_records', 'nutrition_targets', 'programs', 'program_days', 'planned_exercises', 'planned_sets', 'workout_sessions', 'session_exercises', 'set_logs', 'food_logs', 'food_log_items', 'recovery_logs', 'recommendations', 'notifications', 'push_tokens']) {
      expect(file.tables[t]?.length ?? 0, t).toBeGreaterThan(0);
    }
    // Complete: for every table that references users directly with CASCADE,
    // the export holds exactly the rows a direct query finds.
    const direct = await sql<{ child: string; col: string }[]>`
      select kcu.table_name as child, kcu.column_name as col
      from information_schema.referential_constraints rc
      join information_schema.key_column_usage kcu on kcu.constraint_name = rc.constraint_name
      join information_schema.constraint_column_usage ccu on ccu.constraint_name = rc.unique_constraint_name
      where ccu.table_name = 'users' and rc.delete_rule = 'CASCADE' and rc.constraint_schema = 'public'`;
    expect(direct.length).toBeGreaterThan(10);
    for (const { child, col } of direct) {
      const [row] = await sql.unsafe<{ n: number }[]>(`select count(*)::int as n from "${child}" where "${col}" = $1`, [u.id]);
      expect(file.tables[child]?.filter((r2) => r2[col] === u.id).length ?? 0, `${child}.${col}`).toBe(row!.n);
    }
    expect(r.body).toContain('Rajma chawal at home');
    expect(r.body).not.toContain(other.id);
    expect(r.body).not.toContain(other.email);
  });

  it(`export is limited to ${EXPORT_PER_HOUR} an hour per user`, async () => {
    const u = await user();
    for (let i = 0; i < EXPORT_PER_HOUR; i++) expect((await call(u, 'POST', '/user/export', {})).statusCode).toBe(200);
    expect((await call(u, 'POST', '/user/export', {})).statusCode).toBe(429);
    // Another user is unaffected.
    expect((await call(await user(), 'POST', '/user/export', {})).statusCode).toBe(200);
  });

  /* ------------------------------------------------------------ erasure -- */

  /** Every column of every table that can hold text, searched for `needle`. */
  async function residue(needle: string): Promise<string[]> {
    const cols = await sql<{ table_name: string; column_name: string }[]>`
      select c.table_name, c.column_name from information_schema.columns c
      join information_schema.tables t on t.table_name = c.table_name and t.table_schema = c.table_schema and t.table_type = 'BASE TABLE'
      where c.table_schema = 'public' and c.data_type in ('uuid', 'text', 'character varying', 'jsonb', 'json', 'ARRAY')`;
    const hits: string[] = [];
    for (const c of cols) {
      const [row] = await sql.unsafe<{ n: number }[]>(
        `select count(*)::int as n from "${c.table_name}" where "${c.column_name}"::text like $1`,
        [`%${needle}%`],
      );
      if (row!.n > 0) hits.push(`${c.table_name}.${c.column_name} (${row!.n})`);
    }
    return hits;
  }

  it('§23.3 deletion: confirmed by typing DELETE; then no residue anywhere — verified by direct query over every column of every table', async () => {
    const u = await user();
    await lived(u);
    // Someone looked the account up in the admin panel (an audit entry about them).
    const adminToken = `pv-admin-${randomUUID()}`;
    verifier.accept(adminToken, { uid: `pv-admin-uid-${n}`, email: `pv-admin-${n}@vit.ac.in`, claims: { role: 'admin' } });
    await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(adminToken), payload: {} });
    expect((await app.inject({ method: 'GET', url: `/v1/admin/users?id=${u.id}`, headers: headers(adminToken) })).statusCode).toBe(200);
    expect((await residue(u.id)).length).toBeGreaterThan(5);

    expect((await call(u, 'DELETE', '/user', {})).statusCode).toBe(422);
    expect((await call(u, 'DELETE', '/user', { confirm: 'delete' })).statusCode).toBe(422);
    const r = await call(u, 'DELETE', '/user', { confirm: 'DELETE' });
    expect(r.statusCode, r.body).toBe(200);
    expect(r.json()).toEqual({ deleted: true, signInRemoved: true });
    expect(deleter.deleted).toContain(u.uid);

    expect(await residue(u.id)).toEqual([]);
    expect(await residue(u.email)).toEqual([]);
    expect(await residue(u.uid)).toEqual([]);
    // The admin's audit entry stays, anonymous.
    const [kept] = await sql<{ entity_id: string | null; metadata: { subjectDeleted?: boolean } }[]>`
      select entity_id, metadata from audit_logs where action = 'user.lookup' order by occurred_at desc limit 1`;
    expect(kept).toMatchObject({ entity_id: null, metadata: { subjectDeleted: true } });
  });

  it('if Firebase cannot remove the sign-in, FITOS data is still gone and the answer says so', async () => {
    const u = await user();
    deleter.fail = true;
    try {
      const r = await call(u, 'DELETE', '/user', { confirm: 'DELETE' });
      expect(r.json()).toEqual({ deleted: true, signInRemoved: false });
    } finally {
      deleter.fail = false;
    }
    expect(await residue(u.id)).toEqual([]);
  });
});
