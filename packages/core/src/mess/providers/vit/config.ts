/**
 * The six MessIT endpoints, as configuration.
 *
 * This is the ONLY place these URLs appear. Feature code, UI and the
 * recommender all talk to `MessProvider`, so adding VIT Chennai or a different
 * university is a new config + adapter, not a refactor.
 *
 * Verified live on 2026-09-07. Response shape:
 *   { hostel: number, mess: number,
 *     menu: [{ date: "YYYY-MM-DD", menu: [{ type: 1|2|3|4, menu: string }] }] }
 *
 * `type` → meal slot mapping was inferred from content, not documented upstream:
 *   1 = breakfast (idly, dosa, paratha)   2 = lunch (rice, dal, sambar, sweets)
 *   3 = snacks (single item: vada, puff)  4 = dinner (roti, rice, fruit)
 */

import type { MealSlot, MessDescriptor } from '../../types.js';

export const VIT_VELLORE_PROVIDER_ID = 'vit-vellore';

export const MESSIT_BASE_URL = 'https://messit.vinnovateit.com/menu-data';

/** Upstream numeric `type` → our slot. Unknown types are dropped, not guessed. */
export const MESSIT_TYPE_TO_SLOT: Readonly<Record<number, MealSlot>> = {
  1: 'breakfast',
  2: 'lunch',
  3: 'snacks',
  4: 'dinner',
};

export interface MessItEndpoint {
  readonly hostelId: string;
  readonly messId: string;
  readonly hostel: number;
  readonly mess: number;
  readonly url: string;
}

interface EndpointSeed {
  readonly hostelId: string;
  readonly hostelLabel: string;
  readonly messId: string;
  readonly messLabel: string;
  readonly hostel: number;
  readonly mess: number;
  readonly servesNonVeg: boolean;
}

const SEEDS: readonly EndpointSeed[] = [
  { hostelId: 'mens', hostelLabel: "Men's Hostel", messId: 'veg', messLabel: 'Vegetarian', hostel: 1, mess: 2, servesNonVeg: false },
  { hostelId: 'mens', hostelLabel: "Men's Hostel", messId: 'nonveg', messLabel: 'Non-Vegetarian', hostel: 1, mess: 3, servesNonVeg: true },
  { hostelId: 'mens', hostelLabel: "Men's Hostel", messId: 'special', messLabel: 'Special', hostel: 1, mess: 1, servesNonVeg: true },
  { hostelId: 'womens', hostelLabel: "Women's Hostel", messId: 'veg', messLabel: 'Vegetarian', hostel: 2, mess: 2, servesNonVeg: false },
  { hostelId: 'womens', hostelLabel: "Women's Hostel", messId: 'nonveg', messLabel: 'Non-Vegetarian', hostel: 2, mess: 3, servesNonVeg: true },
  { hostelId: 'womens', hostelLabel: "Women's Hostel", messId: 'special', messLabel: 'Special', hostel: 2, mess: 1, servesNonVeg: true },
];

export const VIT_ENDPOINTS: readonly MessItEndpoint[] = SEEDS.map((s) => ({
  hostelId: s.hostelId,
  messId: s.messId,
  hostel: s.hostel,
  mess: s.mess,
  url: `${MESSIT_BASE_URL}/hostel-${s.hostel}-mess-${s.mess}.json`,
}));

export const VIT_DESCRIPTORS: readonly MessDescriptor[] = SEEDS.map((s) => ({
  providerId: VIT_VELLORE_PROVIDER_ID,
  hostelId: s.hostelId,
  hostelLabel: s.hostelLabel,
  messId: s.messId,
  messLabel: s.messLabel,
  servesNonVeg: s.servesNonVeg,
}));

export function endpointFor(hostelId: string, messId: string): MessItEndpoint | null {
  return VIT_ENDPOINTS.find((e) => e.hostelId === hostelId && e.messId === messId) ?? null;
}

export function descriptorFor(hostelId: string, messId: string): MessDescriptor | null {
  return VIT_DESCRIPTORS.find((d) => d.hostelId === hostelId && d.messId === messId) ?? null;
}
