/**
 * Building the food seed (Phase 7): USDA records as-is, the core estimate
 * table carried over unchanged, and composite dishes composed from USDA
 * ingredients. Pure functions — the CLI (scripts/build-food-seed.ts) does the
 * file I/O, and the CI checks reuse `compositeNutrition` / `carriedNutrition`
 * to prove the committed seed is exactly what these rules produce.
 */
import { estimateNutrition } from '@fitos/core/mess/nutrition';
import {
  composeRecipe,
  exactFoodNutrition,
  foodSourceFromNutritionSource,
  normaliseAliases,
  normaliseFoodText,
  roundFoodNutrition,
  scaleFoodNutrition,
  validateFoodNutrition,
  type FoodNutritionRange,
} from '@fitos/core/nutrition/food';
import { foodSeedFileSchema, type FoodNutrition, type FoodSeed } from '@fitos/contracts';

import {
  BUILDER_VERSION,
  SEED_TARGET_APPROX,
  USDA_CITATION,
  USDA_DATASETS,
  USDA_LICENSE,
  carriedSourceRef,
  compositeSourceRef,
  orderFoods,
  usdaSourceRef,
  type CarriedFile,
  type FoodSeedManifest,
  type Per100g,
  type Recipe,
  type RecipesFile,
  type UsdaDatasetKey,
  type UsdaPicksFile,
} from './format.js';
import { usableValues, usdaKey, type UsdaRecord } from './usda.js';

type Confidence = FoodNutrition['confidence'];

function row(
  n: FoodNutritionRange,
  basis: FoodNutrition['basis'],
  servingLabel: string,
  servingGrams: number | null,
  confidence: Confidence,
): FoodNutrition {
  const m = n.macros;
  return {
    basis,
    servingLabel,
    servingGrams,
    kcalLow: m.kcalLow,
    kcalHigh: m.kcalHigh,
    proteinLow: m.proteinLow,
    proteinHigh: m.proteinHigh,
    carbLow: m.carbLow,
    carbHigh: m.carbHigh,
    fatLow: m.fatLow,
    fatHigh: m.fatHigh,
    fibreLow: n.fibre === null ? null : n.fibre.low,
    fibreHigh: n.fibre === null ? null : n.fibre.high,
    confidence,
  };
}

function exactPer100g(v: Per100g): FoodNutritionRange {
  return exactFoodNutrition({ kcal: v.kcal, protein: v.protein, carb: v.carb, fat: v.fat, fibre: v.fibre });
}

/** A direct USDA food's rows: per 100 g, then up to two USDA portions — exact, high confidence. */
export function usdaNutrition(values: Per100g, portions: UsdaRecord['portions']): FoodNutrition[] {
  const per100 = exactPer100g(values);
  return [
    row(roundFoodNutrition(per100, 'nearest'), 'per_100g', '100 g', 100, 'high'),
    ...portions.map((p) => row(roundFoodNutrition(scaleFoodNutrition(per100, p.grams / 100), 'nearest'), 'per_serving', p.label, p.grams, 'high')),
  ];
}

/**
 * The confidence a carried-over estimate is seeded with. Its NUMBERS are
 * core's, unchanged; but a FITOS estimate is never `high` confidence (Gate
 * 7-0), so the few core entries labelled `high` are seeded as `medium`. The
 * manifest records both, so the cap is visible.
 */
export function carriedConfidence(coreConfidence: Confidence): Exclude<Confidence, 'high'> {
  return coreConfidence === 'high' ? 'medium' : coreConfidence;
}

/** A carried-over food's one row: core's own estimate for `coreTerm`, values unchanged. Fibre unknown. */
export function carriedNutrition(coreTerm: string): FoodNutrition {
  const est = estimateNutrition(coreTerm, 'other');
  if (est === null) throw new Error(`core estimate table has no entry for "${coreTerm}"`);
  if (foodSourceFromNutritionSource(est.source) !== 'estimated') throw new Error(`"${coreTerm}" is not an estimate`);
  return row({ macros: est.macros, fibre: null }, 'per_serving', est.servingLabel, est.servingGrams, carriedConfidence(est.confidence));
}

/** Core's own confidence label for `coreTerm` (before the cap). */
export function coreConfidence(coreTerm: string): Confidence {
  const est = estimateNutrition(coreTerm, 'other');
  if (est === null) throw new Error(`core estimate table has no entry for "${coreTerm}"`);
  return est.confidence;
}

/** A composite's one row, computed from the recipe and the per-100 g inputs. */
export function compositeNutrition(recipe: Recipe, per100g: (fdcId: number) => Per100g): FoodNutrition {
  const n = composeRecipe(
    { ingredients: recipe.ingredients, oil: recipe.oil, widening: recipe.widening },
    (id) => exactPer100g(per100g(id)),
  );
  return row(n, 'per_serving', recipe.servingLabel, recipe.servingGrams, recipe.confidence);
}

export interface BuildInputs {
  readonly picks: UsdaPicksFile;
  readonly carried: CarriedFile;
  readonly recipes: RecipesFile;
  readonly usda: ReadonlyMap<string, UsdaRecord>;
}

export interface BuildResult {
  readonly foods: FoodSeed[];
  /** Everything except the checksums, which the CLI adds from the file bytes. */
  readonly manifest: Omit<FoodSeedManifest, 'datasets' | 'inputs' | 'seed'>;
}

/**
 * Resolve an ingredient: the same FDC id may not appear in both datasets, so
 * the first dataset that has it (Foundation, then SR Legacy) is the source.
 */
function findRecord(usda: ReadonlyMap<string, UsdaRecord>, fdcId: number): UsdaRecord {
  for (const ds of Object.keys(USDA_DATASETS) as UsdaDatasetKey[]) {
    const r = usda.get(usdaKey(ds, fdcId));
    if (r !== undefined) return r;
  }
  throw new Error(`FDC ${fdcId} is in neither permitted dataset`);
}

export function buildFoodSeed({ picks, carried, recipes, usda }: BuildInputs): BuildResult {
  const foods: FoodSeed[] = [];
  const usdaFoods: FoodSeedManifest['usdaFoods'] = [];
  const droppedPicks: FoodSeedManifest['droppedPicks'] = [];

  // 1. Direct USDA foods. A pick that is not a usable permitted record is dropped, never estimated.
  for (const pick of picks.picks) {
    const record = usda.get(usdaKey(pick.dataset, pick.fdcId));
    if (record === undefined) {
      droppedPicks.push({ slug: pick.slug, fdcId: pick.fdcId, reason: `not found in ${pick.dataset}` });
      continue;
    }
    const usable = usableValues(record);
    if (!usable.ok) {
      droppedPicks.push({ slug: pick.slug, fdcId: pick.fdcId, reason: usable.reason });
      continue;
    }
    foods.push({
      slug: pick.slug,
      name: record.description,
      brand: null,
      barcode: null,
      source: 'usda',
      sourceRef: usdaSourceRef(record.fdcId, record.dataset),
      isVerified: true,
      aliases: normaliseAliases(record.description, pick.aliases),
      nutrition: usdaNutrition(usable.values, record.portions),
    });
    usdaFoods.push({
      slug: pick.slug,
      fdcId: record.fdcId,
      dataset: record.dataset,
      release: USDA_DATASETS[record.dataset].release,
      description: record.description,
      energyNutrient: record.energyNutrient as '208' | '958' | '957',
      fibreReported: usable.values.fibre !== null,
      portions: record.portions.length,
    });
  }

  // 2. Carried-over core estimates, values straight from core.
  const carriedFoods: FoodSeedManifest['carriedFoods'] = [];
  for (const c of carried.foods) {
    foods.push({
      slug: c.slug,
      name: c.name,
      brand: null,
      barcode: null,
      source: 'estimated',
      sourceRef: carriedSourceRef(c.coreTerm),
      isVerified: false,
      aliases: normaliseAliases(c.name, c.aliases),
      nutrition: [carriedNutrition(c.coreTerm)],
    });
    const core = coreConfidence(c.coreTerm);
    carriedFoods.push({ slug: c.slug, coreTerm: c.coreTerm, coreSource: 'estimated-table', coreConfidence: core, confidence: carriedConfidence(core) });
  }

  // 3. Composite estimates from declared recipes.
  const compositeFoods: FoodSeedManifest['compositeFoods'] = [];
  const compositeInputs: FoodSeedManifest['compositeInputs'] = {};
  for (const recipe of recipes.recipes) {
    const ids = [...recipe.ingredients.map((i) => i.fdcId), ...(recipe.oil === null ? [] : [recipe.oil.fdcId])];
    for (const id of ids) {
      const record = findRecord(usda, id);
      const usable = usableValues(record);
      if (!usable.ok) throw new Error(`recipe ${recipe.id}: ingredient FDC ${id} unusable (${usable.reason})`);
      compositeInputs[String(id)] = { dataset: record.dataset, description: record.description, per100g: usable.values };
    }
    const per100g = (id: number): Per100g => {
      const v = compositeInputs[String(id)];
      if (v === undefined) throw new Error(`no input for FDC ${id}`);
      return v.per100g;
    };
    foods.push({
      slug: recipe.id,
      name: recipe.name,
      brand: null,
      barcode: null,
      source: 'estimated',
      sourceRef: compositeSourceRef(recipe.id, recipe.version),
      isVerified: false,
      aliases: normaliseAliases(recipe.name, recipe.aliases),
      nutrition: [compositeNutrition(recipe, per100g)],
    });
    compositeFoods.push({
      slug: recipe.id,
      recipeId: recipe.id,
      recipeVersion: recipe.version,
      servingLabel: recipe.servingLabel,
      servingGrams: recipe.servingGrams,
      ingredients: recipe.ingredients.map((i) => ({ fdcId: i.fdcId, grams: i.grams, dataset: findRecord(usda, i.fdcId).dataset })),
      oil: recipe.oil,
      widening: recipe.widening,
      confidence: recipe.confidence as 'medium' | 'low',
    });
  }

  // 4. Whole-seed rules: the contract schema, unique slugs and names, valid ranges, no alias that is
  //    another food's name. A seed that breaks any of them is never written.
  const ordered = orderFoods(foods);
  foodSeedFileSchema.parse(ordered);
  assertSeedRules(ordered);

  const sortedInputs: FoodSeedManifest['compositeInputs'] = {};
  for (const key of Object.keys(compositeInputs).sort((a, b) => Number(a) - Number(b))) {
    sortedInputs[key] = compositeInputs[key] as FoodSeedManifest['compositeInputs'][string];
  }
  const counts = {
    total: ordered.length,
    usda: usdaFoods.length,
    estimatedCarried: carriedFoods.length,
    estimatedComposite: compositeFoods.length,
    nutritionRows: ordered.reduce((n, f) => n + f.nutrition.length, 0),
    aliases: ordered.reduce((n, f) => n + f.aliases.length, 0),
    usdaPicksDropped: droppedPicks.length,
    targetApprox: SEED_TARGET_APPROX,
    gapToTarget: Math.max(0, SEED_TARGET_APPROX - ordered.length),
  };
  return {
    foods: ordered,
    manifest: {
      manifestVersion: 1,
      builderVersion: BUILDER_VERSION,
      builder: 'apps/api/src/scripts/build-food-seed.ts',
      excludedSources: [
        'USDA FoodData Central — Branded Foods (industry-provided label data)',
        'USDA FoodData Central — FNDDS / Survey Foods',
        'USDA FoodData Central — Experimental Foods',
        'IFCT 2017 (licensing not confirmed in writing)',
        'INDB (licensing not confirmed in writing)',
      ],
      counts,
      rules: {
        usdaEnergy: 'nutrient 208 (Energy, kcal); if absent 958 (Atwater specific), then 957 (Atwater general)',
        usdaRounding: 'nearest: kcal to 0 decimals, grams to 1 decimal; low == high',
        usdaPortions: 'per 100 g, plus up to two USDA household portions in USDA order (RACC, labels over 60 characters and portions over 1000 g skipped)',
        compositeRounding: 'outward: lows rounded down, highs rounded up (kcal 0 decimals, grams 1 decimal)',
        wideningRule: 'sum ingredients (per-100 g × grams / 100); low end with the least oil, high end with the most; then low × (1 − w), high × (1 + w) with the recipe\'s w',
        fibre: 'null (unknown) when the source does not report it — never 0; a composite is unknown if any ingredient is',
        carriedConfidence: 'carried-over core estimates keep their numbers unchanged; a core confidence of high is seeded as medium (a FITOS estimate is never high)',
      },
      usdaFoods: [...usdaFoods].sort((a, b) => (a.slug < b.slug ? -1 : 1)),
      droppedPicks,
      carriedFoods: [...carriedFoods].sort((a, b) => (a.slug < b.slug ? -1 : 1)),
      compositeFoods: [...compositeFoods].sort((a, b) => (a.slug < b.slug ? -1 : 1)),
      compositeInputs: sortedInputs,
    },
  };
}

/** Rules every seed must satisfy; the builder refuses to write one that breaks them. */
export function assertSeedRules(foods: readonly FoodSeed[]): void {
  const problems: string[] = [];
  const slugs = new Set<string>();
  const names = new Map<string, string>();
  for (const f of foods) {
    if (slugs.has(f.slug)) problems.push(`duplicate slug ${f.slug}`);
    slugs.add(f.slug);
    const key = normaliseFoodText(f.name);
    if (names.has(key)) problems.push(`duplicate name "${f.name}" (${names.get(key)} and ${f.slug})`);
    names.set(key, f.slug);
    for (const n of f.nutrition) {
      const issues = validateFoodNutrition(
        {
          macros: {
            kcalLow: n.kcalLow, kcalHigh: n.kcalHigh, proteinLow: n.proteinLow, proteinHigh: n.proteinHigh,
            carbLow: n.carbLow, carbHigh: n.carbHigh, fatLow: n.fatLow, fatHigh: n.fatHigh,
          },
          fibre: n.fibreLow === null || n.fibreHigh === null ? null : { low: n.fibreLow, high: n.fibreHigh },
        },
        n.basis,
      );
      for (const i of issues) problems.push(`${f.slug} ${n.servingLabel}: ${i.field} ${i.problem}`);
    }
  }
  for (const f of foods) {
    for (const alias of f.aliases) {
      const owner = names.get(alias);
      if (owner !== undefined && owner !== f.slug) problems.push(`${f.slug}: alias "${alias}" is the name of ${owner}`);
    }
  }
  if (problems.length > 0) throw new Error(`food seed rules broken:\n  ${problems.join('\n  ')}`);
}

export { USDA_CITATION, USDA_LICENSE };
