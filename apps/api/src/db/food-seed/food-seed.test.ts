/**
 * Phase 7 — the committed food seed is exactly what the declared rules
 * produce, and the manifest says so truthfully. Runs in CI without the raw
 * USDA downloads: everything a composite was computed from is pinned in the
 * manifest, so each one is recomputed here and compared.
 */
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

import { FOOD_SOURCES as CONTRACT_FOOD_SOURCES } from '@fitos/contracts';
import { estimateNutrition } from '@fitos/core/mess/nutrition';
import { FOOD_SOURCES as CORE_FOOD_SOURCES, normaliseFoodText } from '@fitos/core/nutrition/food';

import { assertSeedRules, carriedNutrition, compositeNutrition } from './build.js';
import {
  FOOD_MANIFEST_FILE,
  FOOD_SEED_FILE,
  FOOD_SOURCES_DIR,
  SEED_TARGET_APPROX,
  USDA_DATASETS,
  carriedFileSchema,
  manifestSchema,
  orderFoods,
  parseSeedFile,
  recipesFileSchema,
  serialise,
  sha256,
  usdaPicksFileSchema,
} from './format.js';

const seedText = readFileSync(FOOD_SEED_FILE, 'utf8');
const manifest = manifestSchema.parse(JSON.parse(readFileSync(FOOD_MANIFEST_FILE, 'utf8')));
const foods = parseSeedFile(seedText);
const inputs = {
  usdaPicks: readFileSync(`${FOOD_SOURCES_DIR}usda-picks.json`, 'utf8'),
  carried: readFileSync(`${FOOD_SOURCES_DIR}carried.json`, 'utf8'),
  recipes: readFileSync(`${FOOD_SOURCES_DIR}recipes.json`, 'utf8'),
};
const picks = usdaPicksFileSchema.parse(JSON.parse(inputs.usdaPicks));
const carried = carriedFileSchema.parse(JSON.parse(inputs.carried));
const recipes = recipesFileSchema.parse(JSON.parse(inputs.recipes));

const bySlug = new Map(foods.map((f) => [f.slug, f]));

describe('vocabulary', () => {
  it('the API contract and core agree on the six food sources', () => {
    expect([...CONTRACT_FOOD_SOURCES]).toEqual([...CORE_FOOD_SOURCES]);
  });
});

describe('manifest integrity', () => {
  it('the seed checksum matches the committed foods.json', () => {
    expect(sha256(seedText)).toBe(manifest.seed.sha256);
  });

  it('the input checksums and versions match the committed source files', () => {
    expect(sha256(inputs.usdaPicks)).toBe(manifest.inputs.usdaPicks.sha256);
    expect(sha256(inputs.carried)).toBe(manifest.inputs.carried.sha256);
    expect(sha256(inputs.recipes)).toBe(manifest.inputs.recipes.sha256);
    expect(manifest.inputs.usdaPicks.version).toBe(picks.version);
    expect(manifest.inputs.carried.version).toBe(carried.version);
    expect(manifest.inputs.recipes.version).toBe(recipes.version);
  });

  it('pins exactly the two permitted USDA datasets and their releases', () => {
    expect(manifest.datasets.map((d) => [d.key, d.release, d.file])).toEqual([
      ['foundation', '2026-04-30', USDA_DATASETS.foundation.file],
      ['sr_legacy', '2018-04', USDA_DATASETS.sr_legacy.file],
    ]);
    for (const d of manifest.datasets) expect(d.sha256).toMatch(/^[0-9a-f]{64}$/);
    expect(manifest.excludedSources.join(' ')).toMatch(/Branded Foods/);
    expect(manifest.excludedSources.join(' ')).toMatch(/IFCT/);
    expect(manifest.excludedSources.join(' ')).toMatch(/INDB/);
  });

  it('counts are the seed as it is — no padding toward the ~500 target', () => {
    const usda = foods.filter((f) => f.source === 'usda').length;
    const carriedN = foods.filter((f) => f.sourceRef.includes('core estimate table')).length;
    const composite = foods.filter((f) => f.sourceRef.includes('composed from USDA ingredients')).length;
    expect(manifest.counts).toMatchObject({
      total: foods.length,
      usda,
      estimatedCarried: carriedN,
      estimatedComposite: composite,
      nutritionRows: foods.reduce((n, f) => n + f.nutrition.length, 0),
      aliases: foods.reduce((n, f) => n + f.aliases.length, 0),
      targetApprox: SEED_TARGET_APPROX,
      gapToTarget: Math.max(0, SEED_TARGET_APPROX - foods.length),
    });
    expect(usda + carriedN + composite).toBe(foods.length);
    expect(manifest.counts.usda + manifest.counts.usdaPicksDropped).toBe(picks.picks.length);
  });
});

describe('determinism', () => {
  it('re-serialising the seed reproduces the committed bytes (ordering, rounding, no timestamps)', () => {
    expect(serialise(orderFoods(foods))).toBe(seedText);
    expect(seedText).not.toMatch(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/);
    expect(seedText.includes('\r')).toBe(false);
  });
});

describe('seed rules', () => {
  it('no duplicate slugs or names, valid ranges everywhere, no alias that is another food\'s name', () => {
    expect(() => assertSeedRules(foods)).not.toThrow();
  });

  it('every food carries a source, provenance and a confidence on every row', () => {
    for (const f of foods) {
      expect(['usda', 'estimated']).toContain(f.source);
      expect(f.sourceRef.length).toBeGreaterThan(0);
      for (const n of f.nutrition) expect(['high', 'medium', 'low']).toContain(n.confidence);
    }
  });

  it('aliases are stored normalised', () => {
    for (const f of foods) for (const a of f.aliases) expect(a).toBe(normaliseFoodText(a));
  });

  it('the approved Indian spelling aliases resolve to the right foods', () => {
    const owner = (alias: string): string[] => foods.filter((f) => f.aliases.includes(alias)).map((f) => f.slug);
    expect(owner('dhal')).toEqual(['dal-tadka']);
    expect(owner('daal')).toEqual(['dal-tadka']);
    expect(owner('panneer 65')).toEqual(['paneer-65']);
    expect(owner('chapathi')).toEqual(['chapati']);
    expect(owner('roti')).toEqual(['chapati']);
    expect(owner('idly')).toEqual(['idli']);
    expect(owner('dosai')).toEqual(['plain-dosa']);
    expect(owner('sambhar')).toEqual(['sambar']);
    expect(owner('biriyani')).toEqual(['veg-biryani']);
    expect(owner('dahi')).toEqual(['curd']);
    expect(owner('raitha')).toEqual(['raita']);
    expect(owner('poori')).toEqual(['puri']);
  });
});

describe('USDA provenance', () => {
  it('every USDA food is a pinned FDC record: verified, exact, high confidence, named as USDA names it', () => {
    const manifestBySlug = new Map(manifest.usdaFoods.map((u) => [u.slug, u]));
    for (const f of foods.filter((x) => x.source === 'usda')) {
      const m = manifestBySlug.get(f.slug);
      expect(m, f.slug).toBeDefined();
      expect(f.sourceRef).toBe(`USDA FoodData Central · ${USDA_DATASETS[m!.dataset].label} · FDC ${m!.fdcId}`);
      expect(f.name).toBe(m!.description);
      expect(f.isVerified).toBe(true);
      expect(f.nutrition[0]).toMatchObject({ basis: 'per_100g', servingLabel: '100 g', servingGrams: 100 });
      for (const n of f.nutrition) {
        expect(n.confidence).toBe('high');
        expect([n.kcalLow, n.proteinLow, n.carbLow, n.fatLow]).toEqual([n.kcalHigh, n.proteinHigh, n.carbHigh, n.fatHigh]);
        // Unknown fibre is null on both ends, never a zero standing in for "not reported".
        expect(n.fibreLow === null).toBe(!m!.fibreReported);
      }
    }
    expect(manifest.usdaFoods).toHaveLength(foods.filter((x) => x.source === 'usda').length);
  });
});

describe('carried-over estimates', () => {
  it('each is core\'s own estimate for its term, unchanged (estimated-table → estimated), fibre unknown', () => {
    expect(manifest.carriedFoods).toHaveLength(carried.foods.length);
    for (const c of carried.foods) {
      const f = bySlug.get(c.slug);
      expect(f, c.slug).toBeDefined();
      expect(f!.source).toBe('estimated');
      expect(f!.isVerified).toBe(false);
      expect(f!.nutrition).toEqual([carriedNutrition(c.coreTerm)]);
      expect(f!.nutrition[0]!.fibreLow).toBeNull();
      expect(f!.nutrition[0]!.confidence).not.toBe('high');
      // The numbers are core's exactly; only a `high` label is capped, and the manifest shows it.
      const est = estimateNutrition(c.coreTerm, 'other')!;
      expect(f!.nutrition[0]).toMatchObject({
        kcalLow: est.macros.kcalLow,
        kcalHigh: est.macros.kcalHigh,
        proteinLow: est.macros.proteinLow,
        proteinHigh: est.macros.proteinHigh,
        carbLow: est.macros.carbLow,
        carbHigh: est.macros.carbHigh,
        fatLow: est.macros.fatLow,
        fatHigh: est.macros.fatHigh,
        servingLabel: est.servingLabel,
        servingGrams: est.servingGrams,
      });
      const m = manifest.carriedFoods.find((x) => x.slug === c.slug)!;
      expect(m.coreConfidence).toBe(est.confidence);
      expect(m.confidence).toBe(est.confidence === 'high' ? 'medium' : est.confidence);
    }
  });
});

describe('composite estimates', () => {
  it('every composite recomputes exactly from its recipe and the pinned USDA inputs', () => {
    const per100g = (id: number) => {
      const v = manifest.compositeInputs[String(id)];
      if (v === undefined) throw new Error(`manifest lacks input FDC ${id}`);
      return v.per100g;
    };
    expect(manifest.compositeFoods).toHaveLength(recipes.recipes.length);
    for (const r of recipes.recipes) {
      const f = bySlug.get(r.id);
      expect(f, r.id).toBeDefined();
      expect(f!.source).toBe('estimated');
      expect(f!.isVerified).toBe(false);
      expect(f!.sourceRef).toBe(`FITOS estimate · composed from USDA ingredients · recipe ${r.id} v${r.version}`);
      expect(f!.nutrition).toEqual([compositeNutrition(r, per100g)]);
      expect(['medium', 'low']).toContain(f!.nutrition[0]!.confidence);
      const m = manifest.compositeFoods.find((c) => c.slug === r.id);
      expect(m).toMatchObject({ recipeId: r.id, recipeVersion: r.version, servingGrams: r.servingGrams, widening: r.widening, oil: r.oil });
      expect(m!.ingredients.map((i) => [i.fdcId, i.grams])).toEqual(r.ingredients.map((i) => [i.fdcId, i.grams]));
    }
  });

  it('an estimate is a range, never a point', () => {
    for (const r of recipes.recipes) {
      const n = bySlug.get(r.id)!.nutrition[0]!;
      expect(n.kcalLow).toBeLessThan(n.kcalHigh);
    }
  });
});
