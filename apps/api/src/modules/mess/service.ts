/**
 * Mess service (Phase 9). Builds menus from the stored snapshots with
 * packages/core (`resolveDayFromSnapshots` — parse, classify, resolve), and
 * attaches each dish's stored estimate (`mess_dish_nutrition`). It never calls
 * MessIT: an upstream outage changes nothing here but the freshness it reports.
 */
import { isMirrorStale } from '@fitos/core/mess/freshness';
import { capMessConfidence } from '@fitos/core/mess/nutrition';
import { resolveDayFromSnapshots, type MenuSnapshot, type SnapshotDay } from '@fitos/core/mess/snapshots';
import { localDateOf } from '@fitos/core/nutrition/log';
import type {
  Mess,
  MessCorrection,
  MessCorrectionRequest,
  MessDish,
  MessDishNutrition,
  MessMenu,
  MessMenuQuery,
  MessProviderInfo,
  MessesResponse,
  MessRef,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import type { MessDishCorrectionRow, MessDishNutritionRow, MessProviderRow, MessRow } from '../../db/schema.js';
import type { MessRepository } from './repository.js';

const numOrNull = (v: string | null): number | null => (v === null ? null : Number(v));

export function providerFrom(p: MessProviderRow): MessProviderInfo {
  return { slug: p.slug, displayName: p.displayName, status: p.status === 'disabled' ? 'disabled' : 'active' };
}

export function nutritionFromRow(r: MessDishNutritionRow): MessDishNutrition {
  return {
    servingLabel: r.servingLabel,
    servingGrams: numOrNull(r.servingGrams),
    kcalLow: Number(r.kcalLow),
    kcalHigh: Number(r.kcalHigh),
    proteinLow: Number(r.proteinLow),
    proteinHigh: Number(r.proteinHigh),
    carbLow: Number(r.carbLow),
    carbHigh: Number(r.carbHigh),
    fatLow: Number(r.fatLow),
    fatHigh: Number(r.fatHigh),
    fibreLow: numOrNull(r.fibreLow),
    fibreHigh: numOrNull(r.fibreHigh),
    confidence: capMessConfidence(r.confidence),
    source: 'estimated',
  };
}

function correctionFrom(r: MessDishCorrectionRow): MessCorrection {
  const diet = r.dietValue === 'veg' || r.dietValue === 'egg' || r.dietValue === 'nonveg' ? r.dietValue : null;
  return {
    id: r.id,
    clientCorrectionId: r.clientCorrectionId,
    dishSlug: r.dishSlug,
    field: r.field as MessCorrection['field'],
    low: numOrNull(r.valueLow),
    high: numOrNull(r.valueHigh),
    diet,
    note: r.note,
    status: r.status as MessCorrection['status'],
    createdAt: r.createdAt.toISOString(),
  };
}

export class MessService {
  constructor(
    private readonly repo: MessRepository,
    /** The user's zone, for "today" (the food-log repository's lookup). */
    private readonly timezoneOf: (userId: string) => Promise<string>,
    /** The user's configured mess, if any. */
    private readonly configuredMess: (userId: string) => Promise<MessRef | null>,
    private readonly now: () => Date = () => new Date(),
  ) {}

  private messFrom(m: MessRow, providerSlug: string, latestPublished: string | null): Mess {
    return {
      code: m.code,
      providerSlug,
      hostelId: m.hostelId,
      hostelLabel: m.hostelLabel,
      messId: m.messId,
      messLabel: m.messLabel,
      servesNonVeg: m.servesNonVeg,
      freshness: {
        lastSuccessAt: m.lastSuccessAt?.toISOString() ?? null,
        lastAttemptAt: m.lastAttemptAt?.toISOString() ?? null,
        lastError: m.lastError === 'unreachable' || m.lastError === 'malformed' ? m.lastError : null,
        stale: isMirrorStale(m.lastSuccessAt, this.now()),
        latestPublishedDate: latestPublished,
      },
    };
  }

  /** The public description of one mess, with its freshness. */
  async describe(mess: MessRow): Promise<Mess> {
    const [provider, latest] = await Promise.all([this.repo.providerById(mess.providerId), this.repo.latestPublishedDates([mess.id])]);
    if (provider === null) throw new AppError('INTERNAL', 'A mess without a provider.');
    return this.messFrom(mess, provider.slug, latest.get(mess.id) ?? null);
  }

  /** The caller's configured mess, or null. */
  async configuredMessRow(userId: string): Promise<MessRow | null> {
    const ref = await this.configuredMess(userId);
    return ref === null ? null : this.repo.messByRef(ref.providerId, ref.hostelId, ref.messId);
  }

  async providers(): Promise<{ items: MessProviderInfo[] }> {
    return { items: (await this.repo.providers()).map(providerFrom) };
  }

  async messes(providerSlug: string): Promise<MessesResponse> {
    const provider = await this.repo.providerBySlug(providerSlug);
    if (provider === null) throw new AppError('NOT_FOUND', 'No such mess provider.');
    const rows = await this.repo.messesOf(provider.id);
    const latest = await this.repo.latestPublishedDates(rows.map((m) => m.id));
    return { provider: providerFrom(provider), items: rows.map((m) => this.messFrom(m, provider.slug, latest.get(m.id) ?? null)) };
  }

  /** Owner D13: the mess a profile names must be one the server lists. */
  async messForRef(ref: MessRef): Promise<MessRow | null> {
    return this.repo.messByRef(ref.providerId, ref.hostelId, ref.messId);
  }

  /**
   * The menu for a date, from the snapshots (owner D5): the newest snapshot
   * that publishes it; else the cycle from the latest; else the cycle over
   * the recent snapshots together; else unavailable.
   */
  async resolveDay(mess: MessRow, date: string): Promise<SnapshotDay> {
    const [exact, latest] = await Promise.all([this.repo.newestSnapshotPublishing(mess.id, date), this.repo.latestSnapshot(mess.id)]);
    const toCore = (s: { id: string; payload: MenuSnapshot['payload'] }): MenuSnapshot => ({ id: s.id, payload: s.payload });
    if (exact !== null) return resolveDayFromSnapshots([toCore(exact)], date, mess.servesNonVeg);
    if (latest === null) return resolveDayFromSnapshots([], date, mess.servesNonVeg);
    const first = resolveDayFromSnapshots([toCore(latest)], date, mess.servesNonVeg);
    if (first.day.resolution.kind !== 'unavailable') return first;
    const recent = await this.repo.recentSnapshots(mess.id);
    return recent.length > 1 ? resolveDayFromSnapshots(recent.map(toCore), date, mess.servesNonVeg) : first;
  }

  /** The slugs on a mess's menu for a date (published or inferred) — what can be logged from it. */
  async dishesOnMenu(mess: MessRow, date: string): Promise<Set<string>> {
    const { day } = await this.resolveDay(mess, date);
    return new Set(day.meals.flatMap((m) => m.dishes.map((d) => d.id)).filter((id) => id !== ''));
  }

  async messByCode(code: string): Promise<MessRow | null> {
    return this.repo.messByCode(code);
  }

  async nutritionFor(slugs: readonly string[]): Promise<Map<string, MessDishNutritionRow>> {
    return this.repo.nutritionFor(slugs);
  }

  async codesByIds(ids: readonly string[]): Promise<Map<string, string>> {
    return this.repo.codesByIds(ids);
  }

  async menu(userId: string, query: MessMenuQuery): Promise<MessMenu> {
    let mess: MessRow | null;
    if (query.mess !== undefined) {
      mess = await this.repo.messByCode(query.mess);
      if (mess === null) throw new AppError('NOT_FOUND', 'No such mess.', [{ path: 'mess', issue: query.mess }]);
    } else {
      const ref = await this.configuredMess(userId);
      mess = ref === null ? null : await this.repo.messByRef(ref.providerId, ref.hostelId, ref.messId);
      if (mess === null) throw new AppError('NOT_FOUND', 'Choose your mess first.', [{ path: 'mess', issue: 'not configured' }]);
    }
    const provider = await this.repo.providerById(mess.providerId);
    if (provider === null) throw new AppError('INTERNAL', 'A mess without a provider.');

    const timezone = await this.timezoneOf(userId);
    const today = localDateOf(this.now(), timezone);
    const date = query.date ?? today;

    const [{ day }, latest] = await Promise.all([this.resolveDay(mess, date), this.repo.latestPublishedDates([mess.id])]);
    const slugs = day.meals.flatMap((m) => m.dishes.map((d) => d.id)).filter((id) => id !== '');
    const [nutrition, pending, logged] = await Promise.all([
      this.repo.nutritionFor(slugs),
      this.repo.pendingCorrectionSlugs(userId, slugs),
      this.repo.loggedDishes(userId, date),
    ]);

    return {
      mess: this.messFrom(mess, provider.slug, latest.get(mess.id) ?? null),
      date,
      today,
      resolution: day.resolution,
      meals: day.meals.map((meal) => ({
        slot: meal.slot,
        rawMenu: meal.rawMenu,
        dishes: meal.dishes
          .filter((d) => d.id !== '')
          .map((d): MessDish => {
            const row = nutrition.get(d.id);
            return {
              slug: d.id,
              name: d.name,
              label: d.label,
              diet: d.diet,
              role: d.role,
              alternatives: [...d.alternatives],
              isAmbient: d.isAmbient,
              nutrition: row === undefined ? null : nutritionFromRow(row),
              correctionPending: pending.has(d.id),
            };
          }),
      })),
      logged,
    };
  }

  /**
   * Owner D17: stored as pending; no estimate changes. The dish must be one a
   * mess serves: it has an estimate, or it is on a current menu.
   */
  async correct(userId: string, slug: string, body: MessCorrectionRequest): Promise<{ correction: MessCorrection; created: boolean }> {
    if (!(await this.dishKnown(slug))) throw new AppError('NOT_FOUND', 'No mess serves that dish.', [{ path: 'slug', issue: slug }]);
    const macro = body.field === 'kcal' || body.field === 'protein' || body.field === 'carb' || body.field === 'fat';
    const { row, created } = await this.repo.insertCorrection({
      dishSlug: slug,
      userId,
      clientCorrectionId: body.clientCorrectionId,
      field: body.field,
      valueLow: macro && body.low !== undefined ? String(body.low) : null,
      valueHigh: macro && body.high !== undefined ? String(body.high) : null,
      dietValue: body.field === 'diet' ? (body.diet ?? null) : null,
      note: body.note ?? null,
    });
    return { correction: correctionFrom(row), created };
  }

  private async dishKnown(slug: string): Promise<boolean> {
    if ((await this.repo.nutritionFor([slug])).has(slug)) return true;
    const messes = await this.repo.allMesses();
    for (const mess of messes) {
      const latest = await this.repo.latestSnapshot(mess.id);
      if (latest === null) continue;
      for (const d of latest.payload.menu) {
        const { day } = resolveDayFromSnapshots([{ id: latest.id, payload: latest.payload }], d.date, mess.servesNonVeg);
        if (day.meals.some((m) => m.dishes.some((x) => x.id === slug))) return true;
      }
    }
    return false;
  }
}
