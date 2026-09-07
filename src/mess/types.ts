/**
 * Provider-agnostic mess/canteen domain types.
 *
 * Nothing in here mentions VIT. `VITMessProvider` is one implementation of
 * `MessProvider`; a second university or a corporate cafeteria plugs in by
 * implementing the same interface. The six MessIT URLs live in config only
 * (see `providers/vit/config.ts`), never inline in feature code.
 */

/** Meal slot. Maps from MessIT's numeric `type` field. */
export type MealSlot = 'breakfast' | 'lunch' | 'snacks' | 'dinner';

/**
 * Dietary classification of a single dish.
 * `unknown` is deliberate and load-bearing: we fail safe rather than guess.
 */
export type DietClass = 'veg' | 'egg' | 'nonveg' | 'unknown';

/**
 * What role a dish plays on a plate. Drives both UI grouping and the
 * recommender's candidate selection.
 */
export type DishRole =
  | 'staple' // roti, rice, phulka — the carb base
  | 'protein' // chicken, paneer, egg, dal-forward mains
  | 'legume' // dal, sambar, channa — protein-bearing but carb-heavy
  | 'vegetable' // poriyal, sabji, kootu
  | 'dairy' // curd, buttermilk, milk
  | 'fruit'
  | 'sweet'
  | 'fried' // vada, samosa, chips, puffs
  | 'beverage'
  | 'condiment' // chutney, pickle, sauce, papad
  | 'other';

/** How much we trust a nutrition estimate. Surfaced in the UI, never hidden. */
export type Confidence = 'high' | 'medium' | 'low';

/** A macro estimate expressed as a range. There is no point estimate by design. */
export interface MacroRange {
  readonly kcalLow: number;
  readonly kcalHigh: number;
  readonly proteinLow: number;
  readonly proteinHigh: number;
  readonly carbLow: number;
  readonly carbHigh: number;
  readonly fatLow: number;
  readonly fatHigh: number;
}

/** Where a nutrition number came from. Required — we never launder estimates as facts. */
export type NutritionSource =
  | 'estimated-table' // our curated dish table (labelled estimate)
  | 'ifct-mapped' // mapped to IFCT/INDB composition data (not yet wired)
  | 'user-corrected'; // the user fixed it; highest trust for that user

export interface DishNutrition {
  readonly servingLabel: string; // "1 katori", "2 pieces", "1 cup"
  readonly servingGrams: number | null; // null when genuinely unknown
  readonly macros: MacroRange;
  readonly confidence: Confidence;
  readonly source: NutritionSource;
}

/** A single parsed dish from a menu string. */
export interface MessDish {
  /** Stable id: slug of the normalised name. Lets us join user corrections across days. */
  readonly id: string;
  /** Cleaned display name, e.g. "Chicken Gravy". */
  readonly name: string;
  /** The exact substring we parsed this from. Kept for debugging bad upstream data. */
  readonly raw: string;
  /** Label prefix stripped from the raw string, e.g. "Non Veg", "Sweet", "Fruits". */
  readonly label: string | null;
  readonly diet: DietClass;
  readonly role: DishRole;
  /** True when the source offered alternatives, e.g. "Coconut Rice / Tamarind Rice". */
  readonly alternatives: readonly string[];
  /** Ambient items present at every meal (bread, tea, jam) — deprioritised in UI. */
  readonly isAmbient: boolean;
  readonly nutrition: DishNutrition | null;
}

export interface MessMeal {
  readonly slot: MealSlot;
  readonly dishes: readonly MessDish[];
  /** Verbatim upstream string. Kept so we can always show "what the mess actually published". */
  readonly rawMenu: string;
}

/**
 * How we arrived at the menu we are showing. This is surfaced in the UI —
 * an inferred menu must never be presented as today's published menu.
 */
export type MenuResolution =
  | { readonly kind: 'exact'; readonly date: string }
  | {
      readonly kind: 'cycle-inferred';
      readonly date: string;
      readonly sourceDate: string;
      readonly cycleLengthDays: number;
    }
  | { readonly kind: 'unavailable'; readonly date: string; readonly latestAvailable: string | null };

export interface MessDay {
  readonly date: string; // ISO yyyy-mm-dd
  readonly meals: readonly MessMeal[];
  readonly resolution: MenuResolution;
}

/** Identifies a mess within a provider's namespace. */
export interface MessRef {
  readonly providerId: string; // 'vit-vellore'
  readonly hostelId: string; // 'mens' | 'womens'
  readonly messId: string; // 'veg' | 'nonveg' | 'special'
}

export interface MessDescriptor extends MessRef {
  readonly hostelLabel: string;
  readonly messLabel: string;
  /** Whether this mess is expected to serve non-veg at all. */
  readonly servesNonVeg: boolean;
}

/**
 * The seam. Everything above the provider (UI, recommender, logging) depends
 * only on this interface.
 */
export interface MessProvider {
  readonly id: string;
  readonly displayName: string;
  listMesses(): Promise<readonly MessDescriptor[]>;
  /** Must never throw for a missing date — return an `unavailable` resolution instead. */
  getDay(ref: MessRef, isoDate: string): Promise<MessDay>;
}

/** Raw MessIT wire format. Exactly what the endpoint returns — no invented fields. */
export interface MessItResponse {
  readonly hostel: number;
  readonly mess: number;
  readonly menu: readonly {
    readonly date: string;
    readonly menu: readonly { readonly type: number; readonly menu: string }[];
  }[];
}
