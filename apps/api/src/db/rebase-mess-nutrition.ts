/**
 * Beta 3.7 (owner 2026-10-25, ADR-036): bring the stored mess-dish estimates
 * up to the current core table (CoFID-calibrated dishes, every estimate at
 * most +-20 %). The mirror stores a dish's estimate once, when it is first
 * seen, so a better table never reaches the rows already there.
 *
 *   docker exec fitos-api-<sha7> node apps/api/dist/db/rebase-mess-nutrition.js
 *   pnpm --filter @fitos/api db:rebase-mess-nutrition            (on the PC)
 *
 * A dish an admin has revised (any revision but the system's own) is left
 * alone. Every change is recorded in mess_dish_nutrition_revisions with the
 * reason `beta-3.7-food-data`. Idempotent: a second run changes nothing.
 * Logged items keep the numbers they were logged with.
 */
import { capMessConfidence, enrichDish } from '@fitos/core/mess/nutrition';
import { parseMenuString } from '@fitos/core/mess/parse';
import { eq, inArray } from 'drizzle-orm';

import { createDatabase, type DatabaseHandle } from './client.js';
import { messDishNutrition, messDishNutritionRevisions } from './schema.js';

export const REBASE_REASON = 'beta-3.7-food-data';
/** Revisions the system wrote (migration 0012, this script); any other reason is an admin's. */
const SYSTEM_REASONS = new Set(['phase-10-estimate-correction', REBASE_REASON]);

type Row = typeof messDishNutrition.$inferSelect;
const FIELDS = ['servingLabel', 'servingGrams', 'kcalLow', 'kcalHigh', 'proteinLow', 'proteinHigh', 'carbLow', 'carbHigh', 'fatLow', 'fatHigh', 'confidence'] as const;

/** The stored fields a row would have if the mirror saw its dish today; null when the table has nothing. */
export function currentEstimate(name: string): Pick<Row, (typeof FIELDS)[number]> | null {
  const dish = parseMenuString(name, { messServesNonVeg: true }).map(enrichDish)[0];
  const n = dish?.nutrition;
  if (n === null || n === undefined) return null;
  return {
    servingLabel: n.servingLabel,
    servingGrams: n.servingGrams === null ? null : String(n.servingGrams),
    kcalLow: String(n.macros.kcalLow),
    kcalHigh: String(n.macros.kcalHigh),
    proteinLow: String(n.macros.proteinLow),
    proteinHigh: String(n.macros.proteinHigh),
    carbLow: String(n.macros.carbLow),
    carbHigh: String(n.macros.carbHigh),
    fatLow: String(n.macros.fatLow),
    fatHigh: String(n.macros.fatHigh),
    confidence: capMessConfidence(n.confidence),
  };
}

const pick = (r: Pick<Row, (typeof FIELDS)[number]>) => Object.fromEntries(FIELDS.map((f) => [f, r[f] === null ? null : f === 'servingLabel' || f === 'confidence' ? r[f] : Number(r[f])]));
const same = (a: Pick<Row, (typeof FIELDS)[number]>, b: Pick<Row, (typeof FIELDS)[number]>) => JSON.stringify(pick(a)) === JSON.stringify(pick(b));

export async function rebaseMessNutrition(db: DatabaseHandle['db']): Promise<{ checked: number; updated: number; adminKept: number }> {
  const rows = await db.select().from(messDishNutrition);
  const revisions = rows.length === 0 ? [] : await db.select({ slug: messDishNutritionRevisions.dishSlug, reason: messDishNutritionRevisions.reason }).from(messDishNutritionRevisions).where(inArray(messDishNutritionRevisions.dishSlug, rows.map((r) => r.dishSlug)));
  const adminEdited = new Set(revisions.filter((r) => !SYSTEM_REASONS.has(r.reason)).map((r) => r.slug));
  let updated = 0;
  for (const row of rows) {
    if (adminEdited.has(row.dishSlug)) continue;
    const next = currentEstimate(row.name);
    if (next === null || same(row, next)) continue;
    await db.transaction(async (tx) => {
      await tx.update(messDishNutrition).set({ ...next, updatedAt: new Date() }).where(eq(messDishNutrition.dishSlug, row.dishSlug));
      await tx.insert(messDishNutritionRevisions).values({ dishSlug: row.dishSlug, reason: REBASE_REASON, previous: pick(row), current: pick(next) });
    });
    updated += 1;
  }
  return { checked: rows.length, updated, adminKept: adminEdited.size };
}

const invokedDirectly = /rebase-mess-nutrition\.(ts|js)$/.test(process.argv[1] ?? '');
if (invokedDirectly) {
  const url = process.env['DATABASE_URL'];
  if (url === undefined) {
    console.error('DATABASE_URL is required');
    process.exit(1);
  }
  const handle = createDatabase(url);
  rebaseMessNutrition(handle.db)
    .then((r) => console.log(`mess dish estimates: ${r.checked} checked, ${r.updated} updated, ${r.adminKept} kept as an admin set them`))
    .catch((error: unknown) => {
      console.error(error);
      process.exitCode = 1;
    })
    .finally(() => void handle.client.end({ timeout: 5 }));
}
