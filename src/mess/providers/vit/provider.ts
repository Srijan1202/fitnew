/**
 * VIT Vellore MessIT adapter.
 *
 * THE PROBLEM THIS FILE EXISTS TO SOLVE
 * On 2026-09-07 the six endpoints were not equally fresh:
 *   hostel-1-mess-2 (men's veg)     → September data, today present
 *   hostel-2-mess-3 (women's nonveg)→ September data, today present
 *   hostel-1-mess-3 (men's nonveg)  → AUGUST ONLY, no data for today
 *   hostel-1-mess-1 (men's special) → AUGUST ONLY, no data for today
 *
 * A naive `find(d => d.date === today)` returns undefined for half the user
 * base. Since the published menu repeats on a fixed cycle (verified: the
 * 2026-09-01 menu is byte-identical to 2026-09-15 and 2026-09-29), we can infer
 * a likely menu from the cycle — but we tag it `cycle-inferred` and the UI says
 * so. An inferred menu is never presented as today's published menu.
 */

import type {
  MessDay, MessDescriptor, MessMeal, MessProvider, MessRef, MessItResponse, MenuResolution,
} from '../../types.js';
import { parseMenuString } from '../../parse.js';
import { enrichDish } from '../../nutrition.js';
import {
  MESSIT_TYPE_TO_SLOT, VIT_DESCRIPTORS, VIT_VELLORE_PROVIDER_ID, descriptorFor, endpointFor,
} from './config.js';

/** Candidate cycle lengths, most likely first. Verified 14 in live data. */
const CANDIDATE_CYCLES = [14, 7, 28] as const;

export type Fetcher = (url: string) => Promise<MessItResponse>;

export const defaultFetcher: Fetcher = async (url) => {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`MessIT ${response.status} for ${url}`);
  return (await response.json()) as MessItResponse;
};

function daysBetween(a: string, b: string): number {
  const ms = Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`);
  return Math.round(ms / 86_400_000);
}

/** Runtime shape check. Upstream is unversioned, so we validate rather than trust. */
export function isMessItResponse(value: unknown): value is MessItResponse {
  if (typeof value !== 'object' || value === null) return false;
  const v = value as Record<string, unknown>;
  if (typeof v['hostel'] !== 'number' || typeof v['mess'] !== 'number') return false;
  if (!Array.isArray(v['menu'])) return false;
  return v['menu'].every((day: unknown) => {
    if (typeof day !== 'object' || day === null) return false;
    const d = day as Record<string, unknown>;
    return typeof d['date'] === 'string' && Array.isArray(d['menu']);
  });
}

/**
 * Detects the repeat cycle by checking whether menus `length` days apart are
 * identical. Requires at least two confirming pairs and no contradictions,
 * so we never invent a cycle from a single coincidence.
 */
export function detectCycleLength(response: MessItResponse): number | null {
  const byDate = new Map<string, string>();
  for (const day of response.menu) {
    const breakfast = day.menu.find((m) => m.type === 1);
    if (breakfast !== undefined) byDate.set(day.date, breakfast.menu);
  }
  for (const length of CANDIDATE_CYCLES) {
    let matches = 0;
    let mismatches = 0;
    for (const [date, menu] of byDate) {
      const shifted = new Date(Date.parse(`${date}T00:00:00Z`) + length * 86_400_000)
        .toISOString()
        .slice(0, 10);
      const other = byDate.get(shifted);
      if (other === undefined) continue;
      if (other === menu) matches += 1;
      else mismatches += 1;
    }
    if (matches >= 2 && mismatches === 0) return length;
  }
  return null;
}

/**
 * Resolves which published date to render for `targetDate`.
 * Never throws — a missing date is a normal, expected outcome.
 */
export function resolveMenuDate(response: MessItResponse, targetDate: string): MenuResolution {
  const dates = response.menu.map((d) => d.date).sort(); // upstream order is NOT sorted
  if (dates.includes(targetDate)) return { kind: 'exact', date: targetDate };

  const latestAvailable = dates.length > 0 ? dates[dates.length - 1] ?? null : null;
  const cycleLengthDays = detectCycleLength(response);
  if (cycleLengthDays === null) {
    return { kind: 'unavailable', date: targetDate, latestAvailable };
  }

  // Prefer the congruent published date closest to the target.
  let best: { date: string; distance: number } | null = null;
  for (const date of dates) {
    const delta = daysBetween(date, targetDate);
    if (delta <= 0) continue; // only project forward from published data
    if (delta % cycleLengthDays !== 0) continue;
    if (best === null || delta < best.distance) best = { date, distance: delta };
  }
  if (best === null) return { kind: 'unavailable', date: targetDate, latestAvailable };

  return {
    kind: 'cycle-inferred',
    date: targetDate,
    sourceDate: best.date,
    cycleLengthDays,
  };
}

function buildMeals(
  response: MessItResponse,
  sourceDate: string,
  servesNonVeg: boolean,
): MessMeal[] {
  const day = response.menu.find((d) => d.date === sourceDate);
  if (day === undefined) return [];

  const meals: MessMeal[] = [];
  for (const entry of day.menu) {
    const slot = MESSIT_TYPE_TO_SLOT[entry.type];
    if (slot === undefined) continue; // unknown type: drop, don't guess
    const dishes = parseMenuString(entry.menu, { messServesNonVeg: servesNonVeg }).map(enrichDish);
    meals.push({ slot, dishes, rawMenu: entry.menu });
  }
  return meals;
}

export function buildDay(
  response: MessItResponse,
  targetDate: string,
  servesNonVeg: boolean,
): MessDay {
  const resolution = resolveMenuDate(response, targetDate);
  const sourceDate =
    resolution.kind === 'exact' ? resolution.date
    : resolution.kind === 'cycle-inferred' ? resolution.sourceDate
    : null;

  return {
    date: targetDate,
    meals: sourceDate === null ? [] : buildMeals(response, sourceDate, servesNonVeg),
    resolution,
  };
}

export class VITMessProvider implements MessProvider {
  readonly id = VIT_VELLORE_PROVIDER_ID;
  readonly displayName = 'VIT Vellore — MessIT';

  readonly #fetcher: Fetcher;
  readonly #cache = new Map<string, { at: number; data: MessItResponse }>();
  readonly #ttlMs: number;

  constructor(fetcher: Fetcher = defaultFetcher, ttlMs = 6 * 60 * 60 * 1000) {
    this.#fetcher = fetcher;
    this.#ttlMs = ttlMs;
  }

  async listMesses(): Promise<readonly MessDescriptor[]> {
    return VIT_DESCRIPTORS;
  }

  async getDay(ref: MessRef, isoDate: string): Promise<MessDay> {
    const endpoint = endpointFor(ref.hostelId, ref.messId);
    const descriptor = descriptorFor(ref.hostelId, ref.messId);
    if (endpoint === null || descriptor === null) {
      throw new Error(`Unknown VIT mess: ${ref.hostelId}/${ref.messId}`);
    }

    const cached = this.#cache.get(endpoint.url);
    let data: MessItResponse;
    if (cached !== undefined && Date.now() - cached.at < this.#ttlMs) {
      data = cached.data;
    } else {
      const fetched = await this.#fetcher(endpoint.url);
      if (!isMessItResponse(fetched)) {
        throw new Error(`MessIT returned an unexpected shape for ${endpoint.url}`);
      }
      data = fetched;
      this.#cache.set(endpoint.url, { at: Date.now(), data });
    }

    return buildDay(data, isoDate, descriptor.servesNonVeg);
  }
}
