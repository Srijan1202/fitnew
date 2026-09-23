/**
 * The food seed's files, their schemas and their byte-exact serialisation
 * (Phase 7). Shared by the builder (which writes them) and the CI checks
 * (which verify them without the raw USDA downloads).
 *
 *   database/seeds/food-sources/usda-picks.json  which USDA records, plus aliases
 *   database/seeds/food-sources/carried.json     which core-table estimates
 *   database/seeds/food-sources/recipes.json     declared composite recipes
 *   database/seeds/foods.json                    the generated seed (committed)
 *   database/seeds/foods.manifest.json           provenance + checksums (committed)
 */
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { z } from 'zod';

import { confidenceSchema, foodSeedFileSchema, type FoodSeed } from '@fitos/contracts';

/** database/seeds at the repo root, resolved from this file (src or dist). */
export const SEEDS_DIR = fileURLToPath(new URL('../../../../../database/seeds/', import.meta.url));
export const FOOD_SOURCES_DIR = `${SEEDS_DIR}food-sources/`;
export const FOOD_SEED_FILE = `${SEEDS_DIR}foods.json`;
export const FOOD_MANIFEST_FILE = `${SEEDS_DIR}foods.manifest.json`;

/** Bumped when the builder's output rules change (rounding, portion choice, ordering). */
export const BUILDER_VERSION = '1.0.0';

/** The original MASTER-SPEC target (~500 common Indian foods). Reported against, never padded to. */
export const SEED_TARGET_APPROX = 500;

export const USDA_DATASETS = {
  foundation: {
    key: 'foundation',
    name: 'USDA FoodData Central — Foundation Foods',
    release: '2026-04-30',
    label: 'Foundation Foods (April 2026)',
    file: 'FoodData_Central_foundation_food_json_2026-04-30.zip',
    json: 'FoodData_Central_foundation_food_json_2026-04-30.json',
    rootKey: 'FoundationFoods',
  },
  sr_legacy: {
    key: 'sr_legacy',
    name: 'USDA FoodData Central — SR Legacy',
    release: '2018-04',
    label: 'SR Legacy (April 2018)',
    file: 'FoodData_Central_sr_legacy_food_json_2018-04.zip',
    json: 'FoodData_Central_sr_legacy_food_json_2018-04.json',
    rootKey: 'SRLegacyFoods',
  },
} as const;
export type UsdaDatasetKey = keyof typeof USDA_DATASETS;
export const usdaDatasetKeySchema = z.enum(['foundation', 'sr_legacy']);

export const USDA_LICENSE =
  'Public domain — "USDA FoodData Central data are in the public domain and they are not copyrighted. They are published under CC0 1.0 Universal (CC0 1.0)." (FDC API guide)';
export const USDA_CITATION = 'U.S. Department of Agriculture, Agricultural Research Service. FoodData Central, 2019. fdc.nal.usda.gov.';

/** Human-readable provenance stored in `foods.source_ref` and shown in the app. */
export function usdaSourceRef(fdcId: number, dataset: UsdaDatasetKey): string {
  return `USDA FoodData Central · ${USDA_DATASETS[dataset].label} · FDC ${fdcId}`;
}
export function carriedSourceRef(coreTerm: string): string {
  return `FITOS estimate · core estimate table (packages/core mess/nutrition.ts) · "${coreTerm}"`;
}
export function compositeSourceRef(recipeId: string, recipeVersion: number): string {
  return `FITOS estimate · composed from USDA ingredients · recipe ${recipeId} v${recipeVersion}`;
}

// ------------------------------------------------------------ input files --

export const usdaPicksFileSchema = z
  .object({
    version: z.number().int().positive(),
    note: z.string(),
    picks: z.array(
      z
        .object({
          slug: z.string().min(1),
          fdcId: z.number().int().positive(),
          dataset: usdaDatasetKeySchema,
          aliases: z.array(z.string().min(1)),
        })
        .strict(),
    ),
  })
  .strict();
export type UsdaPicksFile = z.infer<typeof usdaPicksFileSchema>;

export const carriedFileSchema = z
  .object({
    version: z.number().int().positive(),
    note: z.string(),
    foods: z.array(
      z
        .object({
          slug: z.string().min(1),
          name: z.string().min(1),
          coreTerm: z.string().min(1),
          aliases: z.array(z.string().min(1)),
        })
        .strict(),
    ),
  })
  .strict();
export type CarriedFile = z.infer<typeof carriedFileSchema>;

export const recipeSchema = z
  .object({
    id: z.string().min(1),
    version: z.number().int().positive(),
    name: z.string().min(1),
    aliases: z.array(z.string().min(1)),
    servingLabel: z.string().min(1),
    servingGrams: z.number().positive(),
    confidence: confidenceSchema.exclude(['high']),
    widening: z.number().min(0.05).max(0.5),
    notes: z.string().optional(),
    ingredients: z.array(z.object({ fdcId: z.number().int().positive(), grams: z.number().positive() }).strict()).min(1),
    oil: z
      .object({ fdcId: z.number().int().positive(), gramsLow: z.number().min(0), gramsHigh: z.number().min(0) })
      .strict()
      .nullable(),
  })
  .strict();
export const recipesFileSchema = z
  .object({ version: z.number().int().positive(), note: z.string(), recipes: z.array(recipeSchema) })
  .strict();
export type Recipe = z.infer<typeof recipeSchema>;
export type RecipesFile = z.infer<typeof recipesFileSchema>;

// --------------------------------------------------------------- manifest --

const per100gSchema = z
  .object({ kcal: z.number(), protein: z.number(), carb: z.number(), fat: z.number(), fibre: z.number().nullable() })
  .strict();
export type Per100g = z.infer<typeof per100gSchema>;

const sha256Schema = z.string().regex(/^[0-9a-f]{64}$/);

export const manifestSchema = z
  .object({
    manifestVersion: z.literal(1),
    builderVersion: z.string(),
    builder: z.string(),
    datasets: z.array(
      z
        .object({
          key: usdaDatasetKeySchema,
          name: z.string(),
          release: z.string(),
          releaseDate: z.string(),
          file: z.string(),
          sha256: sha256Schema,
          license: z.string(),
          citation: z.string(),
        })
        .strict(),
    ),
    excludedSources: z.array(z.string()),
    inputs: z
      .object({
        usdaPicks: z.object({ file: z.string(), version: z.number(), sha256: sha256Schema }).strict(),
        carried: z.object({ file: z.string(), version: z.number(), sha256: sha256Schema }).strict(),
        recipes: z.object({ file: z.string(), version: z.number(), sha256: sha256Schema }).strict(),
      })
      .strict(),
    seed: z.object({ file: z.string(), sha256: sha256Schema }).strict(),
    counts: z
      .object({
        total: z.number().int(),
        usda: z.number().int(),
        estimatedCarried: z.number().int(),
        estimatedComposite: z.number().int(),
        nutritionRows: z.number().int(),
        aliases: z.number().int(),
        usdaPicksDropped: z.number().int(),
        targetApprox: z.number().int(),
        gapToTarget: z.number().int(),
      })
      .strict(),
    rules: z
      .object({
        usdaEnergy: z.string(),
        usdaRounding: z.string(),
        usdaPortions: z.string(),
        compositeRounding: z.string(),
        wideningRule: z.string(),
        fibre: z.string(),
        carriedConfidence: z.string(),
      })
      .strict(),
    usdaFoods: z.array(
      z
        .object({
          slug: z.string(),
          fdcId: z.number().int(),
          dataset: usdaDatasetKeySchema,
          release: z.string(),
          description: z.string(),
          energyNutrient: z.enum(['208', '958', '957']),
          fibreReported: z.boolean(),
          portions: z.number().int(),
        })
        .strict(),
    ),
    droppedPicks: z.array(z.object({ slug: z.string(), fdcId: z.number().int(), reason: z.string() }).strict()),
    carriedFoods: z.array(
      z
        .object({
          slug: z.string(),
          coreTerm: z.string(),
          coreSource: z.literal('estimated-table'),
          coreConfidence: confidenceSchema,
          confidence: z.enum(['medium', 'low']),
        })
        .strict(),
    ),
    compositeFoods: z.array(
      z
        .object({
          slug: z.string(),
          recipeId: z.string(),
          recipeVersion: z.number().int(),
          servingLabel: z.string(),
          servingGrams: z.number(),
          ingredients: z.array(z.object({ fdcId: z.number().int(), grams: z.number(), dataset: usdaDatasetKeySchema }).strict()),
          oil: z.object({ fdcId: z.number().int(), gramsLow: z.number(), gramsHigh: z.number() }).strict().nullable(),
          widening: z.number(),
          confidence: z.enum(['medium', 'low']),
        })
        .strict(),
    ),
    /** The exact per-100 g USDA values every composite was computed from. */
    compositeInputs: z.record(
      z.string().regex(/^\d+$/),
      z.object({ dataset: usdaDatasetKeySchema, description: z.string(), per100g: per100gSchema }).strict(),
    ),
  })
  .strict();
export type FoodSeedManifest = z.infer<typeof manifestSchema>;

// ---------------------------------------------------------- serialisation --

export function sha256(text: string): string {
  return createHash('sha256').update(text, 'utf8').digest('hex');
}

/**
 * Byte-exact output: two-space JSON, keys in the order the objects were
 * built, LF line endings, one trailing newline. No timestamps anywhere.
 */
export function serialise(value: unknown): string {
  return `${JSON.stringify(value, null, 2)}\n`;
}

/** Foods in the committed order: by slug. Nutrition rows keep their built order. */
export function orderFoods(foods: readonly FoodSeed[]): FoodSeed[] {
  return [...foods].sort((a, b) => (a.slug < b.slug ? -1 : a.slug > b.slug ? 1 : 0));
}

export function parseSeedFile(text: string): FoodSeed[] {
  return foodSeedFileSchema.parse(JSON.parse(text));
}
