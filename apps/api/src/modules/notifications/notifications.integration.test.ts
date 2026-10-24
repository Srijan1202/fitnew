/**
 * Phase 15 (ADR-021) on real Postgres: settings, the plan and its ledger,
 * the phone's outcome reports, preferences, the §21 cap, FCM registration.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';
import { CURRENT_POLICY_VERSION, NOTIFY_KINDS as CONTRACT_KINDS, notifyPlanResponseSchema, type NotifyPlanResponse } from '@fitos/contracts';
import { TEMPLATES } from '@fitos/core/notify/copy';
import { DAILY_CAP, MIN_GAP_MINUTES, NOTIFY_KINDS as CORE_KINDS } from '@fitos/core/notify/types';
import { minuteOfDay } from '@fitos/core/notify/time';

import { migrateUp } from '../../db/migrate.js';
import { notifyKindEnum } from '../../db/schema.js';
import { seedExercises } from '../../db/seed.js';
import type { FakeTokenVerifier } from '../../test/fake-token-verifier.js';
import { buildDbApp, databaseUrl } from '../../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('/v1/notifications (real Postgres)', { timeout: 60_000 }, () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let app: Awaited<ReturnType<typeof buildDbApp>>['app'];
  let verifier: FakeTokenVerifier;
  let n = 0;

  beforeAll(async () => {
    await migrateUp(url);
    await seedExercises(url);
    sql = postgres(url, { max: 1 });
    ({ app, verifier } = await buildDbApp(url));
  });

  afterAll(async () => {
    await sql`delete from users where firebase_uid like 'nt-%'`;
    await app.close();
    await sql.end({ timeout: 5 });
  });

  interface U {
    token: string;
    id: string;
  }
  const auth = (token: string) => ({ authorization: `Bearer ${token}`, 'x-forwarded-for': `203.0.170.${(n % 200) + 1}` });
  const consent = { policyVersion: CURRENT_POLICY_VERSION, types: ['privacy-policy', 'health-data-processing'] };

  async function user(onboard = true): Promise<U> {
    n += 1;
    const token = `nt-tok-${n}`;
    verifier.accept(token, { uid: `nt-uid-${n}`, email: `nt${n}@vit.ac.in` });
    expect((await app.inject({ method: 'POST', url: '/v1/auth/session', headers: auth(token), payload: {} })).statusCode).toBe(200);
    if (onboard) {
      for (const body of [
        { step: 'goal', goalType: 'muscle-gain' },
        { step: 'about', displayName: 'Persona Kumar', sex: 'male', birthDate: '2004-06-01', heightCm: 175, weightKg: 70, consent },
        { step: 'experience', experienceLevel: 'intermediate', trainingDaysPerWeek: 4, activityLevel: 'light' },
        { step: 'training', trainingLocation: 'commercial-gym', equipment: ['barbell', 'dumbbell', 'machine', 'cable'] },
        { step: 'food', dietType: 'non-vegetarian', allergies: [] },
      ]) {
        const r = await app.inject({ method: 'POST', url: '/v1/onboarding/answer', headers: auth(token), payload: body });
        expect(r.statusCode, r.body).toBe(200);
      }
      expect((await app.inject({ method: 'POST', url: '/v1/onboarding/complete', headers: auth(token), payload: {} })).statusCode).toBe(200);
      expect((await app.inject({ method: 'POST', url: '/v1/training/program/generate', headers: auth(token), payload: {} })).statusCode).toBe(200);
    }
    const [row] = await sql<{ id: string }[]>`select id from users where firebase_uid = ${`nt-uid-${n}`}`;
    return { token, id: row!.id };
  }

  const plan = async (u: U, events: unknown[] = []): Promise<NotifyPlanResponse> => {
    const r = await app.inject({ method: 'POST', url: '/v1/notifications/plan', headers: auth(u.token), payload: { events } });
    expect(r.statusCode, r.body).toBe(200);
    return notifyPlanResponseSchema.parse(r.json());
  };
  const settings = (u: U, patch?: Record<string, unknown>) =>
    patch === undefined
      ? app.inject({ method: 'GET', url: '/v1/notifications/settings', headers: auth(u.token) })
      : app.inject({ method: 'PATCH', url: '/v1/notifications/settings', headers: auth(u.token), payload: patch });
  const ledger = (u: U) =>
    sql<{ id: string; kind: string; local_date: string; status: string; variant: string }[]>`
      select id, kind, local_date, status, variant from notifications where user_id = ${u.id} order by scheduled_for`;

  it('every route is default-deny', async () => {
    const anon = { 'x-forwarded-for': '203.0.171.1' };
    for (const [method, path] of [['GET', '/settings'], ['PATCH', '/settings'], ['POST', '/plan'], ['POST', '/preview'], ['POST', '/token']] as const) {
      expect((await app.inject({ method, url: `/v1/notifications${path}`, headers: anon, payload: {} })).statusCode, path).toBe(401);
    }
  });

  it('one vocabulary: core, contracts and the database agree on the kinds', () => {
    expect([...CONTRACT_KINDS]).toEqual([...CORE_KINDS]);
    expect([...notifyKindEnum.enumValues]).toEqual([...CORE_KINDS]);
  });

  it('settings: §21 defaults (cheeky, weigh-in and check-in off); a patch changes only what it names; junk is refused', async () => {
    const u = await user(false);
    const d = (await settings(u)).json();
    expect(d).toMatchObject({ enabled: true, tone: 'cheeky', quietStart: '22:30', quietEnd: '07:30' });
    expect(d.kinds).toMatchObject({ 'weigh-in': false, 'recovery-checkin': false, 'workout-reminder': true, comeback: true });
    const p = await settings(u, { tone: 'gentle', kinds: { 'weigh-in': true } });
    expect(p.statusCode).toBe(200);
    expect(p.json()).toMatchObject({ tone: 'gentle', kinds: { 'weigh-in': true, 'protein-gap': true } });
    expect((await settings(u)).json().tone).toBe('gentle');
    expect((await settings(u, { quietStart: '25:00' })).statusCode).toBe(422);
    expect((await settings(u, { maxPerDay: 4 })).statusCode).toBe(422);
    // Junk written through the free-form /user/preferences falls back to defaults, field by field.
    await app.inject({ method: 'PATCH', url: '/v1/user/preferences', headers: auth(u.token), payload: { notificationSettings: { tone: 'savage', kinds: { comeback: 'yes' }, quietEnd: '06:00' } } });
    expect((await settings(u)).json()).toMatchObject({ tone: 'cheeky', quietEnd: '06:00', kinds: { comeback: true } });
  });

  it('the plan: FITOS words only, ≤ 4 a day and 2 h apart, ahead of now, each with its cancel rule; the ledger holds it', async () => {
    const u = await user();
    const p = await plan(u);
    expect(p.timeZone).toBe('Asia/Kolkata');
    expect(p.items.length).toBeGreaterThan(0);
    const byDay = new Map<string, number[]>();
    for (const i of p.items) {
      expect(TEMPLATES.some((t) => t.id === i.variant && t.kind === i.kind)).toBe(true);
      expect(new Date(i.at).getTime()).toBeGreaterThan(Date.now() - 5_000);
      byDay.set(i.localDate, [...(byDay.get(i.localDate) ?? []), minuteOfDay(new Date(i.at), p.timeZone)]);
    }
    for (const [, minutes] of byDay) {
      expect(minutes.length).toBeLessThanOrEqual(DAILY_CAP);
      const sorted = [...minutes].sort((a, b) => a - b);
      for (let k = 1; k < sorted.length; k++) expect(sorted[k]! - sorted[k - 1]!).toBeGreaterThanOrEqual(MIN_GAP_MINUTES);
    }
    const protein = p.items.find((i) => i.kind === 'protein-gap');
    if (protein !== undefined) {
      const [t] = await sql<{ protein_g: number }[]>`select protein_g from nutrition_targets where user_id = ${u.id} order by effective_from desc limit 1`;
      expect(protein.cancelOn).toEqual([{ event: 'protein-reached', localDate: protein.localDate, grams: Math.ceil(t!.protein_g * 0.75) }]);
      expect(protein).toMatchObject({ screen: 'food-log', slot: 'dinner' });
    }
    const rows = await ledger(u);
    expect(rows.map((r) => r.id).sort()).toEqual(p.items.map((i) => i.id).sort());
    expect(rows.every((r) => r.status === 'planned')).toBe(true);
    // Planning again keeps the same rows (stable ids) and adds none.
    const again = await plan(u);
    expect(new Set(again.items.map((i) => i.id))).toEqual(new Set(p.items.map((i) => i.id)));
    expect((await ledger(u)).length).toBe(rows.length);
  });

  it("the phone's reports: delivered, opened, cancelled move forward only; another user's ids are ignored; a reported kind is not planned again that day", async () => {
    const a = await user();
    const b = await user();
    const [first, second] = (await plan(a)).items;
    const theirs = (await plan(b)).items[0]!;
    const at = new Date().toISOString();
    await plan(a, [
      { id: first!.id, event: 'delivered', at },
      { id: first!.id, event: 'opened', at },
      { id: first!.id, event: 'delivered', at }, // replayed late: no step back
      { id: second!.id, event: 'cancelled', at },
      { id: theirs.id, event: 'cancelled', at },
    ]);
    const rows = new Map((await ledger(a)).map((r) => [r.id, r]));
    expect(rows.get(first!.id)!.status).toBe('opened');
    expect(rows.get(second!.id)!.status).toBe('cancelled');
    expect((await ledger(b)).find((r) => r.id === theirs.id)!.status).toBe('planned');
    const next = await plan(a);
    expect(next.items.some((i) => i.id === first!.id || i.id === second!.id)).toBe(false);
    expect(next.items.some((i) => i.kind === second!.kind && i.localDate === second!.localDate)).toBe(false);
  });

  it('preferences are respected: a kind off disappears; everything off empties the plan and the future ledger', async () => {
    const u = await user();
    const before = await plan(u);
    const kind = before.items[0]!.kind;
    await settings(u, { kinds: { [kind]: false } });
    expect((await plan(u)).items.some((i) => i.kind === kind)).toBe(false);
    await settings(u, { enabled: false });
    expect((await plan(u)).items).toEqual([]);
    expect((await ledger(u)).filter((r) => r.status === 'planned')).toEqual([]);
  });

  it('a gentle tone setting is every word gentle', async () => {
    const u = await user();
    await settings(u, { tone: 'gentle' });
    const p = await plan(u);
    expect(p.items.length).toBeGreaterThan(0);
    expect(p.items.every((i) => i.tone === 'gentle')).toBe(true);
  });

  it('preview: the words a kind would use, nothing stored', async () => {
    const u = await user();
    const r = await app.inject({ method: 'POST', url: '/v1/notifications/preview', headers: auth(u.token), payload: { kind: 'workout-reminder' } });
    expect(r.statusCode, r.body).toBe(200);
    expect(r.json().title.length).toBeGreaterThan(0);
    expect(await ledger(u)).toEqual([]);
    expect((await app.inject({ method: 'POST', url: '/v1/notifications/preview', headers: auth(u.token), payload: { kind: 'sms' } })).statusCode).toBe(422);
  });

  it('FCM token: 204; the same device signing in as someone else moves to them', async () => {
    const a = await user(false);
    const b = await user(false);
    const token = `fcm-${'x'.repeat(40)}`;
    for (const u of [a, a, b]) {
      expect((await app.inject({ method: 'POST', url: '/v1/notifications/token', headers: auth(u.token), payload: { token, platform: 'android' } })).statusCode).toBe(204);
    }
    const rows = await sql<{ user_id: string }[]>`select user_id from push_tokens where token = ${token}`;
    expect(rows).toEqual([{ user_id: b.id }]);
    expect((await app.inject({ method: 'POST', url: '/v1/notifications/token', headers: auth(a.token), payload: { token, platform: 'ios' } })).statusCode).toBe(422);
  });
});
