/**
 * Exercise library through the HTTP surface, on real Postgres with the real
 * seed. Covers §31 Phase 3: search filters, the acceptance rule "filter by
 * equipment returns only performable exercises", and the seed runner's
 * idempotence.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { EXERCISE_LIST_DEFAULT_LIMIT, type ExerciseDetail, type ExerciseSummary } from '@fitos/contracts';

import { migrateUp } from '../../db/migrate.js';
import { readExerciseSeed, seedExercises } from '../../db/seed.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('GET /v1/exercises (real Postgres, real seed)', () => {
  const url = databaseUrl as string;
  const seed = readExerciseSeed();
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  const token = 'ex-tok';

  beforeAll(async () => {
    await migrateUp(url);
    await seedExercises(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
    verifier.accept(token, { uid: 'ex-uid', email: 'ex@vit.ac.in' });
  });

  afterAll(async () => {
    await app.close();
    await sql.end({ timeout: 5 });
  });

  const get = (path: string) =>
    app.inject({ method: 'GET', url: path, headers: { authorization: `Bearer ${token}` } });

  async function list(query = ''): Promise<{ items: ExerciseSummary[]; total: number; limit: number; offset: number }> {
    const r = await get(`/v1/exercises${query}`);
    expect(r.statusCode, r.body).toBe(200);
    return r.json();
  }

  it('the seed is applied: every file entry is a row, 120+ in total', async () => {
    const all = await list('?limit=200');
    expect(all.total).toBe(seed.length);
    expect(all.total).toBeGreaterThanOrEqual(120);
    expect(all.items.map((i) => i.slug).sort()).toEqual(seed.map((e) => e.slug).sort());
    for (const item of all.items) expect(item.primaryMuscles.length, item.slug).toBeGreaterThan(0);
  });

  it('paginates with a stable order and reports the total', async () => {
    const first = await list();
    expect(first.limit).toBe(EXERCISE_LIST_DEFAULT_LIMIT);
    expect(first.items.length).toBe(EXERCISE_LIST_DEFAULT_LIMIT);
    const second = await list(`?offset=${EXERCISE_LIST_DEFAULT_LIMIT}`);
    expect(second.offset).toBe(EXERCISE_LIST_DEFAULT_LIMIT);
    expect(second.total).toBe(first.total);
    const names = [...first.items, ...second.items].map((i) => i.name);
    expect(names).toEqual([...names].sort((a, b) => a.localeCompare(b)));
    expect(new Set(names).size).toBe(names.length);
  });

  it('filter by equipment returns only performable exercises (acceptance)', async () => {
    // Dumbbells only: every result needs nothing beyond dumbbells and the body.
    const dumbbells = await list('?equipment=dumbbell&limit=200');
    expect(dumbbells.total).toBeGreaterThan(0);
    for (const item of dumbbells.items) {
      for (const q of item.equipment) expect(['dumbbell', 'bodyweight'], item.slug).toContain(q);
    }
    // A barbell-only user must not be shown the leg press.
    const barbell = await list('?equipment=barbell&limit=200');
    expect(barbell.items.map((i) => i.slug)).not.toContain('leg-press');
    expect(barbell.items.map((i) => i.slug)).toContain('barbell-back-squat');
    // Requiring TWO things: the band-assisted pull-up needs both a bar and a band.
    const barOnly = await list('?equipment=pull-up-bar&limit=200');
    expect(barOnly.items.map((i) => i.slug)).toContain('pull-up');
    expect(barOnly.items.map((i) => i.slug)).not.toContain('band-assisted-pull-up');
    const barAndBand = await list('?equipment=pull-up-bar,resistance-band&limit=200');
    expect(barAndBand.items.map((i) => i.slug)).toContain('band-assisted-pull-up');
    // The set is exactly what the seed says is performable, no more, no less.
    const expected = seed
      .filter((e) => e.equipment.every((q) => q === 'dumbbell' || q === 'bodyweight'))
      .map((e) => e.slug)
      .sort();
    expect(dumbbells.items.map((i) => i.slug).sort()).toEqual(expected);
  });

  it('bodyweight is always available, so no equipment at all still returns bodyweight work', async () => {
    const none = await list('?equipment=bodyweight&limit=200');
    expect(none.items.map((i) => i.slug)).toContain('push-up');
    for (const item of none.items) expect(item.equipment, item.slug).toEqual(['bodyweight']);
  });

  it('filters by primary muscle and by movement pattern', async () => {
    const chest = await list('?muscle=chest&limit=200');
    for (const item of chest.items) expect(item.primaryMuscles, item.slug).toContain('chest');
    expect(chest.items.map((i) => i.slug)).not.toContain('barbell-row');

    const hinge = await list('?pattern=hinge&limit=200');
    for (const item of hinge.items) expect(item.movementPattern, item.slug).toBe('hinge');
    expect(hinge.total).toBe(seed.filter((e) => e.movementPattern === 'hinge').length);

    const both = await list('?muscle=glutes&pattern=hinge&equipment=dumbbell&limit=200');
    expect(both.items.map((i) => i.slug)).toContain('dumbbell-romanian-deadlift');
    expect(both.items.map((i) => i.slug)).not.toContain('romanian-deadlift');
  });

  it('searches by name, case-insensitively, and matches hyphenated slugs', async () => {
    const r = await list('?q=PULL%20UP');
    const slugs = r.items.map((i) => i.slug);
    expect(slugs).toContain('pull-up');
    expect(slugs).toContain('band-assisted-pull-up');
    expect(slugs).not.toContain('leg-press');
    expect((await list('?q=zzzz-nothing')).total).toBe(0);
  });

  it('rejects an unknown equipment, muscle, pattern or param with 422', async () => {
    for (const bad of ['?equipment=trap-bar', '?muscle=forearms', '?pattern=twist', '?page=2', '?limit=0']) {
      const r = await get(`/v1/exercises${bad}`);
      expect(r.statusCode, bad).toBe(422);
      expect(r.json().error.code).toBe('VALIDATION_FAILED');
    }
  });

  it('detail carries muscles with contributions, alternatives with reasons, contraindications', async () => {
    const squat = (await list('?q=Barbell%20Back%20Squat')).items.find((i) => i.slug === 'barbell-back-squat')!;
    const r = await get(`/v1/exercises/${squat.id}`);
    expect(r.statusCode).toBe(200);
    const d: ExerciseDetail = r.json();
    const entry = seed.find((e) => e.slug === 'barbell-back-squat')!;

    expect(d.instructions).toEqual(entry.instructions);
    expect(d.defaultIncrementKg).toBe(5);
    expect(d.muscles.filter((m) => m.role === 'primary').map((m) => m.muscleGroup).sort()).toEqual(
      [...entry.primaryMuscles].sort(),
    );
    for (const m of d.muscles) expect(m.contribution).toBe(m.role === 'primary' ? 1 : 0.5);
    expect(d.contraindications.sort()).toEqual([...entry.contraindications].sort());
    expect(d.alternatives.map((a) => `${a.slug}:${a.reason}`).sort()).toEqual(
      entry.alternatives.map((a) => `${a.slug}:${a.reason}`).sort(),
    );
    // Every alternative carries its own id and equipment so the client can
    // navigate and show what it needs without a second call.
    for (const a of d.alternatives) {
      expect(a.id).toMatch(/^[0-9a-f-]{36}$/);
      expect(a.equipment.length).toBeGreaterThan(0);
    }
  });

  it('404 for an unknown id, 422 for a non-uuid', async () => {
    const r = await get('/v1/exercises/00000000-0000-4000-8000-000000000000');
    expect(r.statusCode).toBe(404);
    expect(r.json().error.code).toBe('NOT_FOUND');
    expect((await get('/v1/exercises/not-a-uuid')).statusCode).toBe(422);
  });

  it('the seed is idempotent: a second run changes nothing, including ids and updated_at', async () => {
    const before = await sql<{ id: string; slug: string; updated_at: string; n: string }[]>`
      select e.id, e.slug, e.updated_at::text, (select count(*) from exercise_muscles m where m.exercise_id = e.id)::text as n
      from exercises e order by slug`;
    const result = await seedExercises(url);
    expect(result.exercises).toBe(seed.length);
    const after = await sql<{ id: string; slug: string; updated_at: string; n: string }[]>`
      select e.id, e.slug, e.updated_at::text, (select count(*) from exercise_muscles m where m.exercise_id = e.id)::text as n
      from exercises e order by slug`;
    expect(after).toEqual(before);
    const [alts] = await sql<{ n: string }[]>`select count(*)::text as n from exercise_alternatives`;
    expect(Number(alts!.n)).toBe(seed.reduce((s, e) => s + e.alternatives.length, 0));
  });

  it('the seed replaces join rows wholesale and bumps updated_at on a real change', async () => {
    const entry = seed.find((e) => e.slug === 'push-up')!;
    const edited = seed.map((e) =>
      e.slug === 'push-up' ? { ...e, name: 'Push-Up (edited)', contraindications: ['wrist', 'shoulder'] as const } : e,
    );
    await seedExercises(url, edited as typeof seed);
    const [row] = await sql<{ name: string; parts: string[] }[]>`
      select e.name, coalesce(array_agg(c.body_part order by c.body_part), '{}') as parts
      from exercises e left join exercise_contraindications c on c.exercise_id = e.id
      where e.slug = 'push-up' group by e.id`;
    expect(row!.name).toBe('Push-Up (edited)');
    expect(row!.parts).toEqual(['shoulder', 'wrist']);
    // Restore the real seed; the edit must be undone by it.
    await seedExercises(url);
    const [restored] = await sql<{ name: string; parts: string[] }[]>`
      select e.name, coalesce(array_agg(c.body_part order by c.body_part), '{}') as parts
      from exercises e left join exercise_contraindications c on c.exercise_id = e.id
      where e.slug = 'push-up' group by e.id`;
    expect(restored!.name).toBe(entry.name);
    expect(restored!.parts).toEqual([...entry.contraindications].sort());
  });
});
