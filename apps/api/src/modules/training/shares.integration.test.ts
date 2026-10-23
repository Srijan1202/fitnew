/**
 * Beta 3.3 (ADR-034) on real Postgres: share the active programme as a code
 * (structure only — no weights, no owner), preview it signed in (with the
 * equipment you lack) or on the public page, use it (a copy replaces your
 * active programme, the old one is kept), stop sharing, and the codes go
 * with the account. Behind the share-programme switch.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { myShareSchema, sharedProgrammeSchema, type Program } from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import { seedExercises } from '../../db/seed.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';
import { newShareCode } from './shares.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('shared programmes (real Postgres)', () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  interface U {
    token: string;
    id: string;
  }

  const ipOf = new Map<string, string>();
  const headers = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': ipOf.get(token)! });

  async function user(admin = false): Promise<U> {
    n += 1;
    const token = `sp-tok-${n}`;
    ipOf.set(token, `198.61.${n % 250}.${(n * 7) % 250}`);
    verifier.accept(token, { uid: `sp-uid-${n}`, email: `sp${n}@example.com`, claims: admin ? { role: 'admin' } : {} });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: headers(token), payload: {} })).statusCode).toBe(200);
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`sp-uid-${n}`}`;
    return { token, id: row!.id };
  }

  const call = (u: U, method: 'GET' | 'POST' | 'PUT' | 'DELETE', path: string, payload?: Record<string, unknown>) =>
    app.inject({ method, url: `/v1${path}`, headers: headers(u.token), ...(payload !== undefined ? { payload } : {}) });
  const issue = (r: { json(): unknown }) => (r.json() as { error: { details?: { issue: string }[] } }).error.details?.[0]?.issue;

  /** A two-day programme with weights in it, as its owner typed it. */
  async function programme(u: U, name = 'Push Pull'): Promise<Program> {
    const ex = await sql<{ id: string; slug: string }[]>`
      select id, slug from exercises where slug in ('barbell-bench-press', 'barbell-row', 'lat-pulldown') order by slug`;
    const id = (slug: string) => ex.find((e) => e.slug === slug)!.id;
    const r = await call(u, 'PUT', '/training/program', {
      name,
      days: [
        { dayOfWeek: 1, sessionName: 'Push', exercises: [
          { exerciseId: id('barbell-bench-press'), setCount: 3, repMin: 6, repMax: 8, targetRir: 2, sets: [
            { repsMin: 8, repsMax: 8, weightKg: 60, rir: 2 },
            { repsMin: 8, repsMax: 8, weightKg: 60, rir: 2 },
            { repsMin: 6, repsMax: 6, weightKg: 65, rir: 1 },
          ] },
        ] },
        { dayOfWeek: 4, sessionName: 'Pull', exercises: [
          { exerciseId: id('barbell-row'), setCount: 4, repMin: 8, repMax: 10, targetRir: 2, startingWeightKg: 50 },
          { exerciseId: id('lat-pulldown'), setCount: 3, repMin: 10, repMax: 12, targetRir: 1 },
        ] },
      ],
    });
    expect(r.statusCode, r.body).toBe(200);
    return r.json();
  }

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    await seedExercises(url);
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from feature_flags where key = 'share-programme'`;
    await sql`delete from audit_logs where action = 'flag.set'`;
    await sql`delete from users where firebase_uid like 'sp-uid-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  it('codes use the safe alphabet only', () => {
    let i = 0;
    expect(newShareCode(() => i++)).toBe('234567');
    for (let k = 0; k < 50; k += 1) expect(newShareCode()).toMatch(/^[2-9A-HJKMNP-Z]{6}$/);
  });

  it('share → preview (structure only, what you lack) → use: a copy replaces the active programme, the old one kept', async () => {
    const owner = await user();
    await programme(owner);
    const shared = await call(owner, 'POST', '/training/program/share');
    expect(shared.statusCode, shared.body).toBe(201);
    const share = myShareSchema.parse(shared.json());
    expect(share).toMatchObject({ name: 'Push Pull', url: `https://tryfitos.me/p/${share.code}` });

    // Nothing but structure is stored: no weight, no user id inside the snapshot.
    const [row] = await sql<{ snapshot: unknown }[]>`select snapshot from shared_programmes where code = ${share.code}`;
    const stored = JSON.stringify(row!.snapshot);
    expect(stored).not.toMatch(/weight/i);
    expect(stored).not.toContain(owner.id);

    // A friend with dumbbells only sees what they lack.
    const friend = await user();
    await sql`insert into user_profiles (user_id, equipment) values (${friend.id}, '{dumbbell}')
      on conflict (user_id) do update set equipment = '{dumbbell}'`;
    const preview = sharedProgrammeSchema.parse((await call(friend, 'GET', `/training/shared/${share.code}`)).json());
    expect(preview).toMatchObject({ code: share.code, name: 'Push Pull', daysPerWeek: 2 });
    expect(preview.days).toHaveLength(7);
    const push = preview.days.find((d) => d.dayOfWeek === 1)!;
    expect(push.exercises[0]).toMatchObject({ name: expect.stringMatching(/bench/i), setCount: 3, repMin: 6, repMax: 8 });
    expect(push.exercises[0]!.missingEquipment).toContain('barbell');
    expect(JSON.stringify(preview)).not.toContain(owner.id);

    // The friend already has a programme: it is kept, inactive.
    const before = await programme(friend, 'Mine');
    const used = await call(friend, 'POST', `/training/shared/${share.code}/use`);
    expect(used.statusCode, used.body).toBe(200);
    const copy: Program = used.json();
    expect(copy).toMatchObject({ name: 'Push Pull', source: 'custom', daysPerWeek: 2 });
    expect(copy.id).not.toBe(before.id);
    const sets = copy.days.flatMap((d) => d.exercises.flatMap((x) => x.sets));
    expect(sets.length).toBe(10);
    expect(sets.every((s) => s.weightKg === null)).toBe(true);
    expect(copy.days.find((d) => d.dayOfWeek === 1)!.exercises[0]!.sets.map((s) => [s.repsMin, s.repsMax, s.rir])).toEqual([[8, 8, 2], [8, 8, 2], [6, 6, 1]]);
    const kept = await sql<{ active: boolean }[]>`select active from programs where id = ${before.id}`;
    expect(kept).toEqual([{ active: false }]);

    // The owner's own programme is untouched.
    expect(((await call(owner, 'GET', '/training/program')).json() as Program).name).toBe('Push Pull');
  });

  it('your codes; stop sharing (then 404); the public page reads it without signing in, for tryfitos.me only', async () => {
    const owner = await user();
    await programme(owner, 'Full body');
    const a = myShareSchema.parse((await call(owner, 'POST', '/training/program/share')).json());
    const b = myShareSchema.parse((await call(owner, 'POST', '/training/program/share')).json());
    expect(a.code).not.toBe(b.code);
    expect(((await call(owner, 'GET', '/training/program/shares')).json() as { items: { code: string }[] }).items.map((i) => i.code)).toEqual([b.code, a.code]);

    const pub = await app.inject({ method: 'GET', url: `/v1/shared-programmes/${a.code}`, headers: { 'x-forwarded-for': '198.62.0.1' } });
    expect(pub.statusCode, pub.body).toBe(200);
    expect(pub.headers['access-control-allow-origin']).toBe('https://tryfitos.me');
    expect((pub.json() as { days: { exercises: { missingEquipment: string[] }[] }[] }).days.flatMap((d) => d.exercises).every((x) => x.missingEquipment.length === 0)).toBe(true);
    expect((await app.inject({ method: 'GET', url: '/v1/shared-programmes/not-a-code', headers: { 'x-forwarded-for': '198.62.0.1' } })).statusCode).toBe(422);

    const stranger = await user();
    expect((await call(stranger, 'DELETE', `/training/program/shares/${a.code}`)).statusCode).toBe(404);
    expect((await call(owner, 'DELETE', `/training/program/shares/${a.code}`)).statusCode).toBe(204);
    expect((await call(stranger, 'GET', `/training/shared/${a.code}`)).statusCode).toBe(404);
    expect((await call(stranger, 'POST', `/training/shared/${a.code}/use`)).statusCode).toBe(404);
    expect(((await call(owner, 'GET', '/training/program/shares')).json() as { items: unknown[] }).items).toHaveLength(1);

    // Deleting the account deletes its codes.
    await sql`delete from users where id = ${owner.id}`;
    expect((await sql`select 1 from shared_programmes where code in (${a.code}, ${b.code})`).length).toBe(0);
  });

  it('no programme: nothing to share; switched off: refused everywhere', async () => {
    const u = await user();
    expect(issue(await call(u, 'POST', '/training/program/share'))).toBe('none');
    await programme(u);
    const share = myShareSchema.parse((await call(u, 'POST', '/training/program/share')).json());

    const admin = await user(true);
    expect((await call(admin, 'PUT', '/admin/flags/share-programme', { enabled: false })).statusCode).toBe(200);
    expect(issue(await call(u, 'POST', '/training/program/share'))).toBe('feature-off');
    expect(issue(await call(u, 'GET', `/training/shared/${share.code}`))).toBe('feature-off');
    expect(issue(await call(u, 'POST', `/training/shared/${share.code}/use`))).toBe('feature-off');
    const pub = await app.inject({ method: 'GET', url: `/v1/shared-programmes/${share.code}`, headers: { 'x-forwarded-for': '198.62.0.2' } });
    expect(issue(pub)).toBe('feature-off');
    await call(admin, 'PUT', '/admin/flags/share-programme', { enabled: true });
  });
});
