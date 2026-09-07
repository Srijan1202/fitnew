/**
 * End-to-end walkthrough for User C: VIT hostel student, women's non-veg mess,
 * muscle gain, 59 kg. Runs the real pipeline over real captured mess data.
 *
 * Run: npx tsx test/e2e.demo.ts   (or via `npm run demo`)
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { buildDay } from '../src/mess/providers/vit/provider.js';
import { suggestPlates, currentMealSlot } from '../src/mess/recommend.js';
import { formatEstimate } from '../src/mess/nutrition.js';
import { computeTargets, remaining } from '../src/nutrition/targets.js';
import { summariseTrend, recommendCalorieAdjustment } from '../src/nutrition/trend.js';
import { recommendProgression } from '../src/training/progression.js';
import { topActions } from '../src/recommend/engine.js';
import type { MessItResponse } from '../src/mess/types.js';
import type { WeightEntry } from '../src/nutrition/trend.js';

const load = (name: string): MessItResponse =>
  JSON.parse(
    readFileSync(fileURLToPath(new URL(`./fixtures/${name}.json`, import.meta.url)), 'utf8'),
  ) as MessItResponse;

const rule = (label: string): void => console.log(`\n${'─'.repeat(66)}\n${label}\n`);

/* 1 ─ profile and targets ------------------------------------------------- */

rule('1. PROFILE → TARGETS  (Mifflin-St Jeor, deterministic)');

const targets = computeTargets({
  sex: 'female', ageYears: 20, heightCm: 163, weightKg: 59,
  activity: 'light', trainingDaysPerWeek: 4, goal: 'muscle-gain',
});
console.log(`  Target      ${targets.kcal} kcal · ${targets.proteinG} g protein · ${targets.carbG} C · ${targets.fatG} F`);
for (const line of targets.rationale) console.log(`              ${line}`);

/* 2 ─ weight trend -------------------------------------------------------- */

rule('2. WEIGHT → TREND  (EWMA, ignores daily noise)');

const weights: WeightEntry[] = Array.from({ length: 28 }, (_, i) => {
  const date = new Date(Date.parse('2026-08-11T00:00:00Z') + i * 86_400_000)
    .toISOString().slice(0, 10);
  const noise = i % 2 === 0 ? 0.5 : -0.5;
  return { date, kg: Number((58.6 + 0.022 * i + noise).toFixed(1)) };
});
const trend = summariseTrend(weights);
const lastRaw = weights[weights.length - 1]?.kg ?? 0;
console.log(`  Scale today ${lastRaw.toFixed(1)} kg   ← noisy, never shown as the headline`);
console.log(`  Trend       ${trend.currentTrendKg?.toFixed(2)} kg   (${trend.weeklyChangeKg?.toFixed(2)} kg/week, reliable: ${trend.isReliable})`);

const adjustment = recommendCalorieAdjustment({
  goal: 'muscle-gain', weeklyChangeKg: trend.weeklyChangeKg,
  daysSinceLastAdjustment: 14, bodyweightKg: 59,
});
console.log(`  Adjustment  ${adjustment.shouldAdjust ? `${adjustment.deltaKcal >= 0 ? '+' : ''}${adjustment.deltaKcal} kcal` : 'no change'} — ${adjustment.reason}`);

/* 3 ─ progression --------------------------------------------------------- */

rule('3. TRAINING HISTORY → NEXT LOAD  (double progression + RIR)');

const progression = recommendProgression({
  history: [
    { date: '2026-09-01', sets: [{ weightKg: 32.5, reps: 9, rir: 2 }, { weightKg: 32.5, reps: 8, rir: 2 }, { weightKg: 32.5, reps: 8, rir: 1 }] },
    { date: '2026-09-04', sets: [{ weightKg: 32.5, reps: 10, rir: 2 }, { weightKg: 32.5, reps: 10, rir: 1 }, { weightKg: 32.5, reps: 10, rir: 1 }] },
  ],
  target: { repMin: 8, repMax: 10, targetRir: 2, sets: 3, incrementKg: 2.5 },
});
console.log(`  Barbell Row → ${progression.action}  ${progression.weightKg} kg × ${progression.repTarget} @ ${progression.targetRir} RIR`);
console.log(`  Why:        ${progression.reason}`);

/* 4 ─ mess menu ----------------------------------------------------------- */

rule('4. MESS MENU  (real captured data, women\u2019s non-veg)');

const day = buildDay(load('hostel-2-mess-3'), '2026-09-11', true);
console.log(`  Resolution  ${day.resolution.kind}${day.resolution.kind === 'cycle-inferred' ? ` from ${day.resolution.sourceDate}` : ''}`);

const slot = currentMealSlot(19); // 7pm
const meal = day.meals.find((m) => m.slot === slot);
if (meal === undefined) throw new Error('no dinner');
console.log(`  ${slot.toUpperCase()} — ${meal.dishes.filter((d) => !d.isAmbient).length} dishes parsed from one comma-joined string`);
for (const dish of meal.dishes.filter((d) => !d.isAmbient).slice(0, 12)) {
  const n = dish.nutrition;
  const macro = n === null ? 'no estimate'
    : `${formatEstimate(n.macros.kcalLow, n.macros.kcalHigh, ' kcal')} · ${formatEstimate(n.macros.proteinLow, n.macros.proteinHigh, ' g P')} · ${n.confidence}`;
  console.log(`    ${dish.name.padEnd(22)} ${dish.diet.padEnd(8)} ${dish.role.padEnd(10)} ${macro}`);
}

/* 5 ─ plate recommendation ------------------------------------------------ */

rule('5. "WHAT SHOULD I EAT?"  (bounded search, no LLM)');

const consumed = { kcal: 1500, protein: 48 };
const left = remaining({
  kcalConsumed: consumed.kcal, proteinConsumed: consumed.protein, targets,
});
console.log(`  Eaten       ${consumed.kcal} / ${targets.kcal} kcal · ${consumed.protein} / ${targets.proteinG} g protein`);
console.log(`  Remaining   ${left.kcal} kcal · ${left.protein} g protein\n`);

for (const diet of ['non-vegetarian', 'vegetarian'] as const) {
  const [best] = suggestPlates({
    meal, remainingKcal: left.kcal, remainingProtein: left.protein,
    diet, goal: 'muscle-gain',
  });
  console.log(`  ── ${diet} ──`);
  if (best === undefined) { console.log('     nothing suitable on this menu'); continue; }
  for (const item of best.items) {
    console.log(`     ${item.servings} × ${item.servingLabel.padEnd(14)} ${item.name}`);
  }
  console.log(`     ≈ ${formatEstimate(best.macros.kcalLow, best.macros.kcalHigh, ' kcal')} · ${formatEstimate(best.macros.proteinLow, best.macros.proteinHigh, ' g protein')}  (${best.confidence} confidence)`);
  for (const reason of best.reasons) console.log(`     · ${reason}`);
  console.log('');
}

/* 6 ─ TODAY --------------------------------------------------------------- */

rule('6. TODAY  (ranked actions from the full user model)');

const actions = topActions({
  goal: 'muscle-gain',
  dietPreference: 'non-vegetarian',
  todaysSessionName: 'Pull — Back / Biceps',
  todaysSessionMinutes: 58,
  workoutCompletedToday: false,
  daysSinceLastWorkout: 1,
  neglectedMuscles: ['Legs'],
  leadLiftProgression: progression,
  newPrToday: null,
  kcalConsumed: consumed.kcal,
  kcalTarget: targets.kcal,
  proteinConsumed: consumed.protein,
  proteinTarget: targets.proteinG,
  nextMealSlot: 'dinner',
  messConfigured: true,
  loggedWeightToday: true,
  daysSinceWeighIn: 0,
  pendingCalorieAdjustment: adjustment.shouldAdjust
    ? { deltaKcal: adjustment.deltaKcal, reason: adjustment.reason }
    : null,
  stepsToday: 5200,
  weeklyAdherence: 0.86,
});

for (const action of actions) {
  console.log(`  [${String(action.priority).padStart(2)}] ${action.headline}`);
  console.log(`       ${action.detail}`);
  console.log(`       → ${action.target}  (${action.basis})\n`);
}
