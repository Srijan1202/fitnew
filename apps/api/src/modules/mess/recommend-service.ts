/**
 * "What should I eat?" at one meal of a mess (Phase 10, ADR-015).
 *
 * Gathers the caller's OWN inputs — diet, allergies (severity dropped: it
 * never relaxes the filter), goal, the target in effect, what was eaten,
 * which meals are logged, the last 3 days' mess dishes, a workout completed
 * in the last 3 hours — and the menu with its STORED estimates (the same
 * numbers logging snapshots), then returns core's `recommendMeal` as it is.
 * Plates are meals, never the cheapest dish (ADR-016). Nothing is stored
 * (Phase 11); nothing is rephrased (Phase 14).
 */
import { allergenStatus, type Allergen } from '@fitos/core/mess/allergens';
import { capMessConfidence } from '@fitos/core/mess/nutrition';
import {
  NOTHING_EATEN,
  defaultRecommendationSlot,
  recommendMeal,
  type EatenRanges,
} from '@fitos/core/mess/recommendation';
import type { DishNutrition, MessDay } from '@fitos/core/mess/types';
import { proteinDishOf, type DinnerDish } from '@fitos/core/notify/dinner-dish';
import { addDays, localDateOf, localHourOf } from '@fitos/core/nutrition/log';
import type { MessRecommendQuery, MessRecommendation, MessWeekPlan, RecommendationReason } from '@fitos/contracts';
import { MESS_WEEK_DAYS } from '@fitos/contracts';
import { planWeek } from '@fitos/core/mess/week-plan';
import type { RankedPlate } from '@fitos/core/mess/recommendation';

import { AppError } from '../../lib/errors.js';
import type { MessDishNutritionRow, MessRow } from '../../db/schema.js';
import type { FoodLogRepository } from '../nutrition/log-repository.js';
import type { UserRepository } from '../user/repository.js';
import type { RecommendRepository } from './recommend-repository.js';
import type { MessService } from './service.js';

/** ADR-015 §2: "post-workout" = a session completed in the last 3 hours, today. */
export const POST_WORKOUT_HOURS = 3;

function storedNutrition(row: MessDishNutritionRow): DishNutrition {
  return {
    servingLabel: row.servingLabel,
    servingGrams: row.servingGrams === null ? null : Number(row.servingGrams),
    macros: {
      kcalLow: Number(row.kcalLow), kcalHigh: Number(row.kcalHigh),
      proteinLow: Number(row.proteinLow), proteinHigh: Number(row.proteinHigh),
      carbLow: Number(row.carbLow), carbHigh: Number(row.carbHigh),
      fatLow: Number(row.fatLow), fatHigh: Number(row.fatHigh),
    },
    confidence: capMessConfidence(row.confidence),
    source: 'estimated-table',
  };
}

/** A plate on the wire (the recommendation's and the week plan's). */
function plateOut(p: RankedPlate): MessRecommendation['plates'][number] {
  return {
    rank: p.rank,
    items: p.items.map((i) => ({
      dishSlug: i.dishId,
      name: i.name,
      servings: i.servings,
      servingLabel: i.servingLabel,
      servingGrams: i.servingGrams,
      ...i.macros,
      confidence: capMessConfidence(i.confidence),
      component: i.component,
    })),
    totals: p.macros,
    confidence: capMessConfidence(p.confidence),
    // ADR-016: the meal this plate makes (the tier stays internal).
    structure: { kind: p.structure.kind, missing: [...p.structure.missing] },
    reasons: p.reasons.map((x) => ({ ...x, ...('missing' in x ? { missing: [...x.missing] } : {}) })) as RecommendationReason[],
  };
}

export class MessRecommendService {
  constructor(
    private readonly mess: MessService,
    private readonly users: UserRepository,
    private readonly logs: FoodLogRepository,
    private readonly history: RecommendRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /** The menu for the date with every dish's estimate replaced by the stored one (ADR-014/015); also the food guide's (beta 3.6). */
  async storedMenu(mess: MessRow, date: string): Promise<MessDay> {
    const { day } = await this.mess.resolveDay(mess, date);
    const slugs = day.meals.flatMap((m) => m.dishes.map((d) => d.id)).filter((id) => id !== '');
    const rows = await this.mess.nutritionFor(slugs);
    return {
      ...day,
      meals: day.meals.map((m) => ({
        ...m,
        dishes: m.dishes
          .filter((d) => d.id !== '')
          .map((d) => {
            const row = rows.get(d.id);
            return { ...d, nutrition: row === undefined ? null : storedNutrition(row) };
          }),
      })),
    };
  }

  /**
   * Beta 6.1 (E17): for each date, the dinner dish the protein nudge names —
   * only from a PUBLISHED menu (never one inferred from the cycle), with the
   * recommender's own filters. Nothing without a configured mess.
   */
  async dinnerDishes(userId: string, dates: readonly string[]): Promise<Record<string, DinnerDish>> {
    const mess = await this.mess.configuredMessRow(userId);
    if (mess === null) return {};
    const bundle = await this.users.loadBundle(userId);
    if (bundle === null) return {};
    const filters = {
      diet: bundle.diet?.dietType ?? 'vegetarian',
      allergies: [...new Set(bundle.allergies.map((a) => a.allergen))] as Allergen[],
      excludedDishIds: Array.isArray(bundle.diet?.excludedDishIds) ? (bundle.diet?.excludedDishIds as string[]) : [],
    };
    const out: Record<string, DinnerDish> = {};
    for (const date of dates) {
      const menu = await this.storedMenu(mess, date);
      if (menu.resolution.kind !== 'exact') continue;
      const dish = proteinDishOf(menu.meals.find((m) => m.slot === 'dinner'), filters);
      if (dish !== null) out[date] = dish;
    }
    return out;
  }

  /**
   * Beta 6.1 (premium): today and the next six days, each served meal with
   * the recommender's plate (core `planWeek`); the user's own filters, the
   * targets in effect today, and the dishes eaten in the three days before.
   */
  async weekPlan(userId: string, query: { mess?: string | undefined }): Promise<MessWeekPlan> {
    const bundle = await this.users.loadBundle(userId);
    if (bundle === null) throw new AppError('NOT_FOUND', 'User not found.');
    const today = localDateOf(this.now(), bundle.user.timezone);
    let mess: MessRow | null;
    if (query.mess !== undefined) {
      mess = await this.mess.messByCode(query.mess);
      if (mess === null) throw new AppError('NOT_FOUND', 'No such mess.', [{ path: 'mess', issue: query.mess }]);
    } else {
      mess = await this.mess.configuredMessRow(userId);
      if (mess === null) throw new AppError('NOT_FOUND', 'Choose your mess first.', [{ path: 'mess', issue: 'not configured' }]);
    }
    const diet = bundle.diet?.dietType ?? 'vegetarian';
    const allergies: Allergen[] = [...new Set(bundle.allergies.map((a) => a.allergen))].sort();
    const excluded = Array.isArray(bundle.diet?.excludedDishIds) ? (bundle.diet?.excludedDishIds as string[]) : [];
    const goal = bundle.goal?.goalType ?? 'general';
    const dates = Array.from({ length: MESS_WEEK_DAYS }, (_, i) => addDays(today, i));
    const [menus, targetsRow, history, describedMess] = await Promise.all([
      Promise.all(dates.map((d) => this.storedMenu(mess, d))),
      this.logs.targetsOn(userId, today),
      this.history.varietyDays(userId, addDays(today, -3), addDays(today, -1)),
      this.mess.describe(mess),
    ]);
    const targets = targetsRow === null ? null : { kcal: targetsRow.kcal, proteinG: targetsRow.proteinG, carbG: targetsRow.carbG, fatG: targetsRow.fatG };
    const days = planWeek({ days: menus, diet, allergies, excludedDishIds: excluded, goal, targets, history });
    return {
      mess: describedMess,
      today,
      filters: { diet, allergies },
      goal,
      hasTargets: targets !== null,
      days: days.map((d) => ({
        date: d.date,
        basis: d.basis,
        meals: d.meals.map((m) => ({ slot: m.slot, status: m.status, plate: m.plate === null ? null : plateOut(m.plate) })),
        totals: d.totals,
      })),
    };
  }

  async recommend(userId: string, query: MessRecommendQuery): Promise<MessRecommendation> {
    const bundle = await this.users.loadBundle(userId);
    if (bundle === null) throw new AppError('NOT_FOUND', 'User not found.');
    const tz = bundle.user.timezone;
    const now = this.now();
    const today = localDateOf(now, tz);
    const date = query.date ?? today;
    if (date !== today && date !== addDays(today, 1)) {
      throw new AppError('VALIDATION_FAILED', 'Suggestions are for today or tomorrow.', [{ path: 'date', issue: 'today or tomorrow only' }]);
    }
    const isToday = date === today;

    let mess: MessRow | null;
    if (query.mess !== undefined) {
      mess = await this.mess.messByCode(query.mess);
      if (mess === null) throw new AppError('NOT_FOUND', 'No such mess.', [{ path: 'mess', issue: query.mess }]);
    } else {
      mess = await this.mess.configuredMessRow(userId);
      if (mess === null) throw new AppError('NOT_FOUND', 'Choose your mess first.', [{ path: 'mess', issue: 'not configured' }]);
    }

    const loggedSlots = isToday ? await this.history.loggedSlots(userId, date) : [];
    const slot = query.slot ?? defaultRecommendationSlot(isToday, localHourOf(now, tz), loggedSlots).slot;

    // The most restrictive diet when none was ever chosen: unknown is never treated as safe.
    const diet = bundle.diet?.dietType ?? 'vegetarian';
    // Severity is deliberately dropped here: it never relaxes the filter (owner D2).
    const allergies: Allergen[] = [...new Set(bundle.allergies.map((a) => a.allergen))].sort();
    const excluded = Array.isArray(bundle.diet?.excludedDishIds) ? (bundle.diet?.excludedDishIds as string[]) : [];
    const goal = bundle.goal?.goalType ?? 'general';

    const [menu, targetsRow, totals, varietyDays, completed, describedMess] = await Promise.all([
      this.storedMenu(mess, date),
      this.logs.targetsOn(userId, date),
      isToday ? this.logs.dayTotals(userId, date) : Promise.resolve(null),
      this.history.varietyDays(userId, addDays(date, -3), addDays(date, -1)),
      isToday ? this.history.completedSince(userId, new Date(now.getTime() - POST_WORKOUT_HOURS * 3_600_000)) : Promise.resolve([]),
      this.mess.describe(mess),
    ]);
    const postWorkout = completed.some((at) => at.getTime() <= now.getTime() && localDateOf(at, tz) === today);
    const eaten: EatenRanges =
      totals === null
        ? NOTHING_EATEN
        : {
            kcalLow: Number(totals.kcalLow), kcalHigh: Number(totals.kcalHigh),
            proteinLow: Number(totals.proteinLow), proteinHigh: Number(totals.proteinHigh),
            carbLow: Number(totals.carbLow), carbHigh: Number(totals.carbHigh),
            fatLow: Number(totals.fatLow), fatHigh: Number(totals.fatHigh),
          };
    const targets =
      targetsRow === null
        ? null
        : { kcal: targetsRow.kcal, proteinG: targetsRow.proteinG, carbG: targetsRow.carbG, fatG: targetsRow.fatG };

    const r = recommendMeal({
      menu,
      slot,
      diet,
      allergies,
      excludedDishIds: excluded,
      goal,
      targets,
      eaten,
      loggedSlots,
      varietyDays,
      postWorkout,
    });

    return {
      status: r.status,
      mess: describedMess,
      date,
      today,
      slot,
      slotAlreadyLogged: loggedSlots.includes(slot),
      loggable: isToday,
      resolution: menu.resolution,
      basis: r.basis,
      filters: { diet, allergies },
      goal,
      target: r.target,
      postWorkout,
      plates: r.plates.map(plateOut),
      shortfall: r.shortfall,
      dishes: r.dishes.map((o) => ({
        dishSlug: o.dish.id,
        name: o.dish.name,
        diet: o.dish.diet,
        onPlate: o.onPlate,
        reasons: o.reasons.map((x) => ({ ...x, ...('ranks' in x ? { ranks: [...x.ranks] } : {}) })) as RecommendationReason[],
        alternatives: o.dish.alternatives.map((name, i) => {
          const altDiet = o.dish.alternativeDiets[i] ?? 'unknown';
          return { name, diet: altDiet, allergens: allergies.map((a) => ({ allergen: a, status: allergenStatus(name, a, altDiet) })) };
        }),
      })),
      smallestMealKcal: r.smallestMealKcal,
    };
  }
}
