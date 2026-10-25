/**
 * Beta 3.7 (ADR-036) on real Postgres: stored mess-dish estimates follow the
 * better core table — with a revision for every change — except where an
 * admin set them; a second run changes nothing.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import postgres from 'postgres';

import { createDatabase, type DatabaseHandle } from './client.js';
import { migrateUp } from './migrate.js';
import { REBASE_REASON, currentEstimate, rebaseMessNutrition } from './rebase-mess-nutrition.js';
import { databaseUrl } from '../test/build-test-app.js';

const describeIfDb = databaseUrl !== undefined ? describe : describe.skip;

describeIfDb('rebase-mess-nutrition (real Postgres)', () => {
  const url = databaseUrl as string;
  let sql: postgres.Sql;
  let handle: DatabaseHandle;
  const slugs = ['rebase-sambar', 'rebase-admin-sambar', 'rebase-unknown'];

  beforeAll(async () => {
    await migrateUp(url);
    sql = postgres(url, { max: 1 });
    handle = createDatabase(url);
    await sql`delete from mess_dish_nutrition where dish_slug in ${sql(slugs)}`;
    // Two "Sambar" rows at the old estimate (85-145), one of them revised by an admin, and a dish the table cannot name.
    for (const slug of slugs) {
      await sql`insert into mess_dish_nutrition (dish_slug, name, serving_label, serving_grams, kcal_low, kcal_high, protein_low, protein_high, carb_low, carb_high, fat_low, fat_high, confidence)
        values (${slug}, ${slug === 'rebase-unknown' ? 'Zqxv special' : 'Sambar'}, '1 katori', 150, 85, 145, 3.5, 6, 12, 19, 2, 5, 'medium')`;
    }
    await sql`insert into mess_dish_nutrition_revisions (dish_slug, reason, previous, current) values ('rebase-admin-sambar', 'checked the mess kitchen', '{}', '{}')`;
  });

  afterAll(async () => {
    await sql`delete from mess_dish_nutrition where dish_slug in ${sql(slugs)}`;
    await handle.client.end({ timeout: 5 });
    await sql.end({ timeout: 5 });
  });

  it('updates the table-made rows with a revision, keeps an admin\'s, and is idempotent', async () => {
    const first = await rebaseMessNutrition(handle.db);
    expect(first.updated).toBeGreaterThanOrEqual(1);
    const want = currentEstimate('Sambar')!;
    const [s] = await sql<{ kcal_low: string; kcal_high: string }[]>`select kcal_low, kcal_high from mess_dish_nutrition where dish_slug = 'rebase-sambar'`;
    expect([Number(s!.kcal_low), Number(s!.kcal_high)]).toEqual([Number(want.kcalLow), Number(want.kcalHigh)]);
    const revs = await sql<{ reason: string; previous: { kcalLow: number } }[]>`select reason, previous from mess_dish_nutrition_revisions where dish_slug = 'rebase-sambar'`;
    expect(revs).toEqual([{ reason: REBASE_REASON, previous: expect.objectContaining({ kcalLow: 85, kcalHigh: 145 }) }]);

    const [admin] = await sql<{ kcal_low: string }[]>`select kcal_low from mess_dish_nutrition where dish_slug = 'rebase-admin-sambar'`;
    expect(Number(admin!.kcal_low)).toBe(85);

    const second = await rebaseMessNutrition(handle.db);
    expect(second.updated).toBe(0);
  });
});
