/**
 * Food logging service (Phase 8). Every number comes from packages/core:
 * the portion (`resolvePortion`), the snapshot (`snapshotNutrition`), the
 * totals (`rollupDay`) and what remains (`remainingForDay`). This layer
 * fetches, guards ownership and maps; it computes nothing itself.
 *
 * The snapshot is taken HERE, from the food row as it is at log time, and
 * stored in full on the item. Nothing reads the food table to show history.
 *
 * Phase 9: a mess dish is logged the same way. Its stored estimate
 * (`mess_dish_nutrition`) is the row, snapshotted now; the item keeps only the
 * dish slug as provenance (owner D10). Saved meals keep a mess dish as a mess
 * dish and re-snapshot its current estimate when logged (owner D11).
 */
import { capMessConfidence } from '@fitos/core/mess/nutrition';
import { exactFoodNutrition, roundFoodNutrition, type FoodNutritionRange } from '@fitos/core/nutrition/food';
import {
  checkLogDate,
  localDateOf,
  remainingForDay,
  resolvePortion,
  rollupDay,
  snapshotNutrition,
  type DayTotals,
} from '@fitos/core/nutrition/log';
import type {
  CreateLogRequest,
  CreateLogResponse,
  CreateSavedMealRequest,
  FoodLog,
  FoodLogItem,
  LogFoodItemRequest,
  LogMessDishRequest,
  NutritionDay,
  NutritionTotals,
  QuickAdd,
  RecentFoodsResponse,
  SavedMeal,
  SavedMealItem,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { DailyNutritionRow, FoodLogItemRow, FoodNutritionRow, MessDishNutritionRow, SavedMealRow } from '../../db/schema.js';
import type { MessService } from '../mess/service.js';
import { nutritionFromRow } from '../mess/service.js';
import { toContract as targetsToContract } from '../user/targets.service.js';
import type { FoodDetailRows, FoodRepository } from './repository.js';
import type { FoodLogRepository, LogWithItems, NewLogItem } from './log-repository.js';
import { foodFrom, nutritionFrom } from './service.js';

const QUICK_ADD_NAME = 'Quick add';

/** A saved meal's stored item (jsonb). The response adds the food's current row. */
type StoredSavedItem =
  | { kind: 'food'; foodId: string; foodName: string; basis: 'per_100g' | 'per_serving'; servingLabel: string; servings: number; grams: number | null }
  | { kind: 'quick-add'; name: string; kcal: number; proteinG: number; carbG: number; fatG: number; fibreG: number | null }
  | { kind: 'mess'; dishSlug: string; name: string; servings: number };

const num = (v: string): number => Number(v);
const numOrNull = (v: string | null): number | null => (v === null ? null : Number(v));
const str = (v: number): string => String(v);
const strOrNull = (v: number | null): string | null => (v === null ? null : String(v));

function rangeOfRow(n: FoodNutritionRow): FoodNutritionRange {
  return {
    macros: {
      kcalLow: num(n.kcalLow), kcalHigh: num(n.kcalHigh),
      proteinLow: num(n.proteinLow), proteinHigh: num(n.proteinHigh),
      carbLow: num(n.carbLow), carbHigh: num(n.carbHigh),
      fatLow: num(n.fatLow), fatHigh: num(n.fatHigh),
    },
    fibre: n.fibreLow === null || n.fibreHigh === null ? null : { low: num(n.fibreLow), high: num(n.fibreHigh) },
  };
}

/** A mess dish's stored estimate as a row: always a range; fibre unknown unless stored. */
function rangeOfMessRow(n: MessDishNutritionRow): FoodNutritionRange {
  return {
    macros: {
      kcalLow: num(n.kcalLow), kcalHigh: num(n.kcalHigh),
      proteinLow: num(n.proteinLow), proteinHigh: num(n.proteinHigh),
      carbLow: num(n.carbLow), carbHigh: num(n.carbHigh),
      fatLow: num(n.fatLow), fatHigh: num(n.fatHigh),
    },
    fibre: n.fibreLow === null || n.fibreHigh === null ? null : { low: num(n.fibreLow), high: num(n.fibreHigh) },
  };
}

function rangeOfItem(i: FoodLogItemRow): FoodNutritionRange {
  return {
    macros: {
      kcalLow: num(i.kcalLow), kcalHigh: num(i.kcalHigh),
      proteinLow: num(i.proteinLow), proteinHigh: num(i.proteinHigh),
      carbLow: num(i.carbLow), carbHigh: num(i.carbHigh),
      fatLow: num(i.fatLow), fatHigh: num(i.fatHigh),
    },
    fibre: i.fibreLow === null || i.fibreHigh === null ? null : { low: num(i.fibreLow), high: num(i.fibreHigh) },
  };
}

function snapshotColumns(s: FoodNutritionRange): Pick<NewLogItem, 'kcalLow' | 'kcalHigh' | 'proteinLow' | 'proteinHigh' | 'carbLow' | 'carbHigh' | 'fatLow' | 'fatHigh' | 'fibreLow' | 'fibreHigh'> {
  const m = s.macros;
  return {
    kcalLow: str(m.kcalLow), kcalHigh: str(m.kcalHigh),
    proteinLow: str(m.proteinLow), proteinHigh: str(m.proteinHigh),
    carbLow: str(m.carbLow), carbHigh: str(m.carbHigh),
    fatLow: str(m.fatLow), fatHigh: str(m.fatHigh),
    fibreLow: s.fibre === null ? null : str(s.fibre.low),
    fibreHigh: s.fibre === null ? null : str(s.fibre.high),
  };
}

export function totalsFrom(t: DayTotals): NutritionTotals {
  const m = t.macros;
  return {
    ...m,
    fibreKnownLow: t.fibreKnown.low,
    fibreKnownHigh: t.fibreKnown.high,
    fibreUnknownItems: t.fibreUnknownItems,
    itemCount: t.itemCount,
  };
}

function dayTotalsOfRow(r: DailyNutritionRow | null): DayTotals {
  if (r === null) return rollupDay([]);
  return {
    macros: {
      kcalLow: num(r.kcalLow), kcalHigh: num(r.kcalHigh),
      proteinLow: num(r.proteinLow), proteinHigh: num(r.proteinHigh),
      carbLow: num(r.carbLow), carbHigh: num(r.carbHigh),
      fatLow: num(r.fatLow), fatHigh: num(r.fatHigh),
    },
    fibreKnown: { low: num(r.fibreKnownLow), high: num(r.fibreKnownHigh) },
    fibreUnknownItems: r.fibreUnknownItems,
    itemCount: r.itemCount,
  };
}

function itemFrom(i: FoodLogItemRow): FoodLogItem {
  return {
    id: i.id,
    position: i.position,
    foodId: i.foodId,
    messDishSlug: i.messDishSlug,
    foodName: i.foodName,
    foodSource: i.foodSource,
    basis: i.basis,
    servingLabel: i.servingLabel,
    servingGrams: numOrNull(i.servingGrams),
    servings: num(i.servings),
    grams: numOrNull(i.grams),
    kcalLow: num(i.kcalLow),
    kcalHigh: num(i.kcalHigh),
    proteinLow: num(i.proteinLow),
    proteinHigh: num(i.proteinHigh),
    carbLow: num(i.carbLow),
    carbHigh: num(i.carbHigh),
    fatLow: num(i.fatLow),
    fatHigh: num(i.fatHigh),
    fibreLow: numOrNull(i.fibreLow),
    fibreHigh: numOrNull(i.fibreHigh),
    confidence: i.confidence,
  };
}

export function logFrom(l: LogWithItems): FoodLog {
  return {
    id: l.log.id,
    clientLogId: l.log.clientLogId,
    loggedAt: l.log.loggedAt.toISOString(),
    localDate: l.log.localDate,
    mealSlot: l.log.mealSlot,
    entryMethod: l.log.entryMethod,
    savedMealId: l.log.savedMealId,
    messCode: l.messCode,
    items: l.items.map(itemFrom),
    totals: totalsFrom(rollupDay(l.items.map(rangeOfItem))),
  };
}

function invalid(path: string, issue: string, message = 'That portion cannot be logged.'): AppError {
  return new AppError('VALIDATION_FAILED', message, [{ path, issue }]);
}

/** The quick-add item: the user's own numbers, exact, never verified (owner J6). */
function quickAddItem(q: QuickAdd | Extract<StoredSavedItem, { kind: 'quick-add' }>, position: number): NewLogItem {
  const name = 'kind' in q ? q.name : q.name ?? QUICK_ADD_NAME;
  const values = roundFoodNutrition(
    exactFoodNutrition({ kcal: q.kcal, protein: q.proteinG, carb: q.carbG, fat: q.fatG, fibre: q.fibreG ?? null }),
    'nearest',
  );
  return {
    position,
    foodId: null,
    messDishSlug: null,
    foodName: name,
    foodSource: 'user',
    basis: null,
    servingLabel: null,
    servingGrams: null,
    servings: '1',
    grams: null,
    ...snapshotColumns(values),
    confidence: 'medium',
  };
}

export class FoodLogService {
  constructor(
    private readonly logs: FoodLogRepository,
    private readonly foods: FoodRepository,
    private readonly now: () => Date = () => new Date(),
    /** Phase 9: mess menus and dish estimates. */
    private readonly mess: MessService | null = null,
  ) {}

  private messOrThrow(): MessService {
    if (this.mess === null) throw new AppError('INTERNAL', 'Mess logging is not wired on this server.');
    return this.mess;
  }

  /**
   * A mess dish snapshot: its stored estimate x the portion (owner D10). The
   * estimate is a per-serving row; grams only when the serving has a weight.
   * Confidence is capped at medium again here (the database also refuses high).
   */
  private messItem(row: MessDishNutritionRow, req: { servings?: number | undefined; grams?: number | undefined }, position: number, path: string): NewLogItem {
    const servingGrams = numOrNull(row.servingGrams);
    const portion = resolvePortion(
      { basis: 'per_serving', servingGrams },
      req.servings !== undefined ? { servings: req.servings } : { grams: req.grams as number },
    );
    if (!portion.ok) throw invalid(req.servings !== undefined ? `${path}.servings` : `${path}.grams`, portion.problem);
    const snap = snapshotNutrition(rangeOfMessRow(row), portion.portion.servings);
    return {
      position,
      foodId: null,
      messDishSlug: row.dishSlug,
      foodName: row.name,
      foodSource: 'estimated',
      basis: 'per_serving',
      servingLabel: row.servingLabel,
      servingGrams: row.servingGrams,
      servings: String(Math.round(portion.portion.servings * 10_000) / 10_000),
      grams: strOrNull(portion.portion.grams),
      ...snapshotColumns(snap),
      confidence: capMessConfidence(row.confidence),
    };
  }

  /** Each dish must be on that mess menu for that date and have an estimate. */
  private async messItems(code: string, menuDate: string, reqs: readonly LogMessDishRequest[]): Promise<{ messId: string; items: NewLogItem[] }> {
    const mess = this.messOrThrow();
    const row = await mess.messByCode(code);
    if (row === null) throw new AppError('NOT_FOUND', 'No such mess.', [{ path: 'mess', issue: code }]);
    const onMenu = await mess.dishesOnMenu(row, menuDate);
    reqs.forEach((r, n) => {
      if (!onMenu.has(r.dishSlug)) {
        throw new AppError('NOT_FOUND', 'That dish is not on this mess menu for that day.', [{ path: `items.${n}.dishSlug`, issue: r.dishSlug }]);
      }
    });
    const estimates = await mess.nutritionFor(reqs.map((r) => r.dishSlug));
    const items = reqs.map((r, n) => {
      const est = estimates.get(r.dishSlug);
      if (est === undefined) {
        throw invalid(`items.${n}.dishSlug`, `"${r.dishSlug}" has no estimate yet`, 'That dish has no nutrition estimate yet; use quick add.');
      }
      return this.messItem(est, r, n, `items.${n}`);
    });
    return { messId: row.id, items };
  }

  /** A food item snapshot: the visible food's named row × the portion. */
  private foodItem(food: FoodDetailRows, req: Pick<LogFoodItemRequest, 'basis' | 'servingLabel' | 'servings' | 'grams'>, position: number, path: string): NewLogItem {
    const row = food.nutrition.find((n) => n.basis === req.basis && n.servingLabel === req.servingLabel);
    if (row === undefined) throw invalid(`${path}.servingLabel`, `"${food.food.name}" has no "${req.servingLabel}" (${req.basis}) row`);
    const portion = resolvePortion(
      { basis: row.basis, servingGrams: numOrNull(row.servingGrams) },
      req.servings !== undefined ? { servings: req.servings } : { grams: req.grams as number },
    );
    if (!portion.ok) throw invalid(req.servings !== undefined ? `${path}.servings` : `${path}.grams`, portion.problem);
    const snap = snapshotNutrition(rangeOfRow(row), portion.portion.servings);
    return {
      position,
      foodId: food.food.id,
      foodName: food.food.name,
      foodSource: food.food.source,
      basis: row.basis,
      servingLabel: row.servingLabel,
      servingGrams: row.servingGrams,
      servings: String(Math.round(portion.portion.servings * 10_000) / 10_000),
      grams: strOrNull(portion.portion.grams),
      ...snapshotColumns(snap),
      confidence: row.confidence,
      messDishSlug: null,
    };
  }

  /** Visible foods by id (Phase 7 rule: global + the caller's own), 404 for any other. */
  private async visibleFoods(userId: string, ids: readonly string[]): Promise<Map<string, FoodDetailRows>> {
    const unique = [...new Set(ids)];
    const found = await this.foods.details(unique, userId);
    const byId = new Map(found.map((f) => [f.food.id, f]));
    for (const id of unique) {
      if (!byId.has(id)) throw new AppError('NOT_FOUND', 'That food is not in your library.', [{ path: 'foodId', issue: id }]);
    }
    return byId;
  }

  async day(userId: string, date: string): Promise<NutritionDay> {
    const timezone = await this.logs.timezoneOf(userId);
    const today = localDateOf(this.now(), timezone);
    if (date > today) throw invalid('date', 'a future day has no log yet', 'That day has not happened yet.');
    const [logs, totalsRow, targetsRow] = await Promise.all([
      this.logs.dayLogs(userId, date),
      this.logs.dayTotals(userId, date),
      this.logs.targetsOn(userId, date),
    ]);
    const totals = dayTotalsOfRow(totalsRow);
    const targets = targetsRow === null ? null : targetsToContract(targetsRow);
    return {
      date,
      today,
      timezone,
      targets,
      totals: totalsFrom(totals),
      remaining: targets === null ? null : remainingForDay(totals, targets),
      logs: logs.map(logFrom),
    };
  }

  async today(userId: string): Promise<NutritionDay> {
    const timezone = await this.logs.timezoneOf(userId);
    return this.day(userId, localDateOf(this.now(), timezone));
  }

  /**
   * Logs food. Retry-safe (owner J12): the same `clientLogId` returns the log
   * already made — 200, nothing counted twice — even if the body differs.
   */
  async create(userId: string, body: CreateLogRequest): Promise<CreateLogResponse & { created: boolean }> {
    const existing = await this.logs.byClientId(userId, body.clientLogId);
    if (existing !== null) return { log: logFrom(existing), day: await this.day(userId, existing.log.localDate), created: false };

    const timezone = await this.logs.timezoneOf(userId);
    const now = this.now();
    const loggedAt = body.loggedAt === undefined ? now : new Date(body.loggedAt);
    const localDate = localDateOf(loggedAt, timezone);
    const dateCheck = checkLogDate(localDate, localDateOf(now, timezone));
    if (!dateCheck.ok) {
      throw dateCheck.problem === 'future'
        ? invalid('loggedAt', 'that day has not happened yet', 'Food can only be logged for today or earlier.')
        : invalid('loggedAt', 'more than 30 days ago', 'Food can be logged up to 30 days back.');
    }

    let items: NewLogItem[];
    let savedMealId: string | null = null;
    let messId: string | null = null;
    switch (body.entryMethod) {
      case 'search': {
        const foods = await this.visibleFoods(userId, body.items.map((i) => i.foodId));
        items = body.items.map((req, n) => this.foodItem(foods.get(req.foodId) as FoodDetailRows, req, n, `items.${n}`));
        break;
      }
      case 'quick-add':
        items = [quickAddItem(body.quickAdd, 0)];
        break;
      case 'saved-meal': {
        const meal = await this.logs.savedMeal(userId, body.savedMealId);
        if (meal === null) throw new AppError('NOT_FOUND', 'That saved meal does not exist.');
        savedMealId = meal.id;
        items = await this.expandSavedMeal(userId, meal);
        break;
      }
      case 'mess': {
        const resolved = await this.messItems(body.mess, body.menuDate, body.items);
        messId = resolved.messId;
        items = resolved.items;
        break;
      }
    }

    const { created } = await this.logs.insertLog({
      userId,
      clientLogId: body.clientLogId,
      loggedAt,
      localDate,
      mealSlot: body.mealSlot,
      entryMethod: body.entryMethod,
      savedMealId,
      messId,
      items,
    });
    const stored = await this.logs.byClientId(userId, body.clientLogId);
    if (stored === null) throw new AppError('INTERNAL', 'The log was saved but could not be read back.');
    return { log: logFrom(stored), day: await this.day(userId, stored.log.localDate), created };
  }

  /**
   * Food items re-snapshot the food's CURRENT row; quick-add items keep their
   * values; mess items re-snapshot the dish's CURRENT estimate (owner D11).
   */
  private async expandSavedMeal(userId: string, meal: SavedMealRow): Promise<NewLogItem[]> {
    const stored = meal.items as StoredSavedItem[];
    const foodIds = stored.flatMap((i) => (i.kind === 'food' ? [i.foodId] : []));
    const found = await this.foods.details([...new Set(foodIds)], userId);
    const byId = new Map(found.map((f) => [f.food.id, f]));
    const messSlugs = stored.flatMap((i) => (i.kind === 'mess' ? [i.dishSlug] : []));
    const estimates = messSlugs.length === 0 ? new Map<string, MessDishNutritionRow>() : await this.messOrThrow().nutritionFor(messSlugs);
    return stored.map((item, n) => {
      if (item.kind === 'quick-add') return quickAddItem(item, n);
      if (item.kind === 'mess') {
        const est = estimates.get(item.dishSlug);
        if (est === undefined) throw invalid(`items.${n}`, `"${item.name}" has no estimate any more`, 'A dish in this meal has no estimate any more.');
        return this.messItem(est, { servings: item.servings }, n, `items.${n}`);
      }
      const food = byId.get(item.foodId);
      if (food === undefined) throw invalid(`items.${n}`, `"${item.foodName}" is no longer in your library`, 'A food in this meal is no longer available.');
      return this.foodItem(food, { basis: item.basis, servingLabel: item.servingLabel, servings: item.servings }, n, `items.${n}`);
    });
  }

  /** Owner J9: the whole log, by client id; idempotent. The response is the log's day. */
  async remove(userId: string, clientLogId: string): Promise<{ day: NutritionDay }> {
    const result = await this.logs.deleteLog(userId, clientLogId);
    if (result === null) throw new AppError('NOT_FOUND', 'That log does not exist.');
    return { day: await this.day(userId, result.localDate) };
  }

  async recent(userId: string, limit: number): Promise<RecentFoodsResponse> {
    const rows = await this.logs.recentFoods(userId, limit);
    // Visibility again at read time: a food that is no longer yours is not offered.
    const found = await this.foods.details(rows.map((r) => r.foodId), userId);
    const byId = new Map(found.map((f) => [f.food.id, f]));
    return {
      items: rows.flatMap((r) => {
        const food = byId.get(r.foodId);
        if (food === undefined) return [];
        return [
          {
            food: foodFrom(food, userId),
            lastLoggedAt: r.loggedAt.toISOString(),
            lastBasis: r.basis,
            lastServingLabel: r.servingLabel,
            lastServings: Number(r.servings),
          },
        ];
      }),
    };
  }

  // ------------------------------------------------------------ saved meals --

  private async mealFrom(userId: string, row: SavedMealRow): Promise<SavedMeal> {
    const stored = row.items as StoredSavedItem[];
    const foodIds = stored.flatMap((i) => (i.kind === 'food' ? [i.foodId] : []));
    const found = await this.foods.details([...new Set(foodIds)], userId);
    const byId = new Map(found.map((f) => [f.food.id, f]));
    const messSlugs = stored.flatMap((i) => (i.kind === 'mess' ? [i.dishSlug] : []));
    const estimates =
      messSlugs.length === 0 || this.mess === null ? new Map<string, MessDishNutritionRow>() : await this.mess.nutritionFor(messSlugs);
    const items: SavedMealItem[] = stored.map((i) => {
      if (i.kind === 'quick-add') return i;
      if (i.kind === 'mess') {
        const est = estimates.get(i.dishSlug);
        return { ...i, row: est === undefined ? null : nutritionFromRow(est) };
      }
      const food = byId.get(i.foodId);
      const row0 = food?.nutrition.find((n) => n.basis === i.basis && n.servingLabel === i.servingLabel);
      return { ...i, row: row0 === undefined ? null : nutritionFrom(row0) };
    });
    return { id: row.id, clientMealId: row.clientMealId, name: row.name, items, createdAt: row.createdAt.toISOString() };
  }

  async savedMeals(userId: string): Promise<{ items: SavedMeal[] }> {
    const rows = await this.logs.savedMeals(userId);
    return { items: await Promise.all(rows.map((r) => this.mealFrom(userId, r))) };
  }

  /** Owner J7: from logged meals only. Retry-safe by `clientMealId`. */
  async createSavedMeal(userId: string, body: CreateSavedMealRequest): Promise<{ meal: SavedMeal; created: boolean }> {
    const existing = await this.logs.savedMealByClientId(userId, body.clientMealId);
    if (existing !== null) return { meal: await this.mealFrom(userId, existing), created: false };
    const logs = await this.logs.logsByClientIds(userId, body.fromClientLogIds);
    if (logs.length !== new Set(body.fromClientLogIds).size) {
      throw new AppError('NOT_FOUND', 'A meal can only be saved from your own logged food.');
    }
    const items: StoredSavedItem[] = logs.flatMap((l) =>
      l.items.map((i): StoredSavedItem =>
        // Owner D11: a mess dish stays a mess dish (slug + portion), never an exact quick add.
        i.messDishSlug !== null
          ? { kind: 'mess', dishSlug: i.messDishSlug, name: i.foodName, servings: Number(i.servings) }
          : i.foodId !== null && i.basis !== null && i.servingLabel !== null
          ? { kind: 'food', foodId: i.foodId, foodName: i.foodName, basis: i.basis, servingLabel: i.servingLabel, servings: Number(i.servings), grams: numOrNull(i.grams) }
          : {
              kind: 'quick-add',
              name: i.foodName,
              kcal: Number(i.kcalLow),
              proteinG: Number(i.proteinLow),
              carbG: Number(i.carbLow),
              fatG: Number(i.fatLow),
              fibreG: numOrNull(i.fibreLow),
            },
      ),
    );
    if (items.length > 50) throw invalid('fromClientLogIds', 'a saved meal holds at most 50 items');
    const { row, created } = await this.logs.insertSavedMeal({ userId, clientMealId: body.clientMealId, name: body.name, items });
    return { meal: await this.mealFrom(userId, row), created };
  }

  async deleteSavedMeal(userId: string, id: string): Promise<void> {
    if (!(await this.logs.deleteSavedMeal(userId, id))) throw new AppError('NOT_FOUND', 'That saved meal does not exist.');
  }
}
