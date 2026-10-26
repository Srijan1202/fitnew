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
import { FRIED_KINDS, cofidNutrition, energyDisagreement, friedKindOf, ifctNutrition, indbNames, indbNutrition } from './sources.js';
import {
  FOOD_MANIFEST_FILE,
  FOOD_SEED_FILE,
  FOOD_SOURCES_DIR,
  INDB_SOURCE_REF,
  SEED_TARGET_APPROX,
  USDA_DATASETS,
  carriedFileSchema,
  cofidFileSchema,
  cofidPicksFileSchema,
  ifctFileSchema,
  indbFileSchema,
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
const ifct = ifctFileSchema.parse(JSON.parse(readFileSync(`${FOOD_SOURCES_DIR}ifct2017.json`, 'utf8')));
const indb = indbFileSchema.parse(JSON.parse(readFileSync(`${FOOD_SOURCES_DIR}indb.json`, 'utf8')));
const cofid = cofidFileSchema.parse(JSON.parse(readFileSync(`${FOOD_SOURCES_DIR}cofid.json`, 'utf8')));
const cofidPicks = cofidPicksFileSchema.parse(JSON.parse(readFileSync(`${FOOD_SOURCES_DIR}cofid-picks.json`, 'utf8')));
const replaced = new Set(cofidPicks.replace.map((r) => r.slug));

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

  it('pins exactly the two permitted USDA datasets and, from beta 3.7, the measured sources\' downloads', () => {
    expect(manifest.datasets.filter((d) => d.key === 'foundation' || d.key === 'sr_legacy').map((d) => [d.key, d.release, d.file])).toEqual([
      ['foundation', '2026-04-30', USDA_DATASETS.foundation.file],
      ['sr_legacy', '2018-04', USDA_DATASETS.sr_legacy.file],
    ]);
    for (const d of manifest.datasets) expect(d.sha256).toMatch(/^[0-9a-f]{64}$/);
    const measured = (key: string) => manifest.datasets.filter((d) => d.key === key).map((d) => [d.file, d.sha256]);
    expect(measured('ifct2017')).toEqual(ifct.raw.map((r) => [r.file, r.sha256]));
    expect(measured('indb')).toEqual(indb.raw.map((r) => [r.file, r.sha256]));
    expect(measured('cofid2021')).toEqual(cofid.raw.map((r) => [r.file, r.sha256]));
    expect(manifest.excludedSources.join(' ')).toMatch(/Branded Foods/);
  });

  it('counts are the seed as it is — no padding toward the ~500 target', () => {
    const usda = foods.filter((f) => f.source === 'usda').length;
    const carriedN = foods.filter((f) => f.sourceRef.includes('core estimate table')).length;
    const composite = foods.filter((f) => f.sourceRef.includes('composed from USDA ingredients')).length;
    const of = (s: string) => foods.filter((f) => f.source === s).length;
    expect(manifest.counts).toMatchObject({
      total: foods.length,
      usda,
      estimatedCarried: carriedN,
      estimatedComposite: composite + replaced.size,
      ifct: of('ifct'),
      ifctSkipped: ifct.foods.length - of('ifct'),
      indb: of('indb'),
      cofidNew: cofidPicks.foods.length,
      cofidReplaced: replaced.size,
      nutritionRows: foods.reduce((n, f) => n + f.nutrition.length, 0),
      aliases: foods.reduce((n, f) => n + f.aliases.length, 0),
      targetApprox: SEED_TARGET_APPROX,
      gapToTarget: Math.max(0, SEED_TARGET_APPROX - foods.length),
    });
    expect(usda + carriedN + composite + of('ifct') + of('indb') + of('cofid')).toBe(foods.length);
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
      expect(['usda', 'estimated', 'ifct', 'indb', 'cofid']).toContain(f.source);
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
      // Beta 3.7: a recipe CoFID measured is checked under "measured sources".
      if (replaced.has(r.id)) continue;
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

describe('measured sources (beta 3.7, ADR-036)', () => {
  it('every IFCT food recomputes exactly from ifct2017.json: per 100 g, verified, cited by code', () => {
    const byRef = new Map(foods.filter((f) => f.source === 'ifct').map((f) => [f.sourceRef, f]));
    expect(manifest.ifctFoods).toHaveLength(byRef.size);
    for (const i of ifct.foods) {
      const f = byRef.get(`IFCT 2017 (NIN-ICMR) · food ${i.code}`);
      const result = ifctNutrition(i);
      if ('skip' in result) {
        expect(f).toBeUndefined();
        expect(manifest.ifctSkipped).toContainEqual({ code: i.code, name: i.name, reason: result.skip });
        continue;
      }
      expect(f, i.code).toBeDefined();
      expect(f!.isVerified).toBe(true);
      expect(f!.nutrition).toEqual([result.nutrition]);
    }
  });

  it('a measured or estimated food\'s energy is what its macros give (4/4/9, within 25 %); USDA keeps its own food-specific factors', () => {
    for (const f of foods.filter((x) => x.source !== 'usda')) {
      for (const n of f.nutrition) {
        const mid = (lo: number, hi: number) => (lo + hi) / 2;
        const why = energyDisagreement(mid(n.kcalLow, n.kcalHigh), mid(n.proteinLow, n.proteinHigh), mid(n.carbLow, n.carbHigh), mid(n.fatLow, n.fatHigh));
        expect(why, `${f.slug} ${n.servingLabel}`).toBeNull();
      }
    }
    // IFCT's 0 kJ oils get IFCT's own factors: ghee is ~884 kcal per 100 g, not 0.
    expect(bySlug.get('ghee-ifct')?.nutrition[0]).toMatchObject({ kcalLow: 857, kcalHigh: 900, fatHigh: 100 });
    // The source rows that fail it are left out and named: INDB's soups, IFCT's skinless chicken leg.
    expect(manifest.indbSkipped.find((s) => s.name === 'Egg drop soup')?.reason).toMatch(/^energy 85 kcal but its macros give/);
    expect(manifest.ifctSkipped.find((s) => s.code === 'N001')?.reason).toMatch(/^energy 384 kcal but its macros give 192/);
  });

  it('every INDB food recomputes exactly from indb.json; a deep-fried one only by a checked kind; no whole dish; never verified', () => {
    const seeded = new Map(manifest.indbFoods.map((e) => [e.code, e]));
    expect(foods.filter((f) => f.source === 'indb')).toHaveLength(seeded.size);
    for (const r of indb.recipes) {
      const entry = seeded.get(r.code);
      if (entry === undefined) {
        expect(manifest.indbSkipped.some((s) => s.code === r.code), r.code).toBe(true);
        continue;
      }
      const f = bySlug.get(entry.slug)!;
      const result = indbNutrition(r);
      expect('nutrition' in result, r.code).toBe(true);
      const fried = r.deepFry === null ? null : friedKindOf(r.name)!.kind;
      expect(entry.fried, r.code).toBe(fried);
      expect(f.sourceRef).toBe(INDB_SOURCE_REF(r.code, fried));
      expect(f.isVerified).toBe(false);
      expect(f.name).toBe(indbNames(r.name).name);
      expect(f.nutrition).toEqual([(result as { nutrition: unknown }).nutrition]);
    }
    // A deep-fried recipe of no checked kind is never a food.
    for (const r of indb.recipes.filter((x) => x.perUnit !== null && x.deepFry !== null && friedKindOf(x.name) === null)) {
      expect(manifest.indbSkipped.find((s) => s.code === r.code)?.reason, r.code).toMatch(/^(deep-fried|FITOS already has)/);
    }
    expect(manifest.counts.indbFried).toBe(manifest.indbFoods.filter((e) => e.fried !== null).length);
  });

  it('CoFID: a replaced FITOS dish keeps its slug, name and serving with CoFID\'s numbers; the plain foods are added', () => {
    const c = new Map(cofid.foods.map((f) => [f.code, f]));
    for (const r of cofidPicks.replace) {
      const f = bySlug.get(r.slug)!;
      const recipe = recipes.recipes.find((x) => x.id === r.slug)!;
      expect(f.source).toBe('cofid');
      expect(f.name).toBe(recipe.name);
      expect(f.nutrition).toEqual([
        cofidNutrition(c.get(r.code)!, recipe.servingGrams, 'dish', recipe.servingLabel),
        cofidNutrition(c.get(r.code)!, 100, 'dish', '100 g'),
      ]);
    }
    for (const p of cofidPicks.foods) expect(bySlug.get(p.slug)?.source).toBe('cofid');
  });

  it('every range is at most +-20 % around its middle (the owner\'s "too wide"), apart from tiny amounts', () => {
    for (const f of foods) {
      for (const n of f.nutrition) {
        const mid = (n.kcalLow + n.kcalHigh) / 2;
        if (mid < 20) continue;
        expect((n.kcalHigh - n.kcalLow) / 2, `${f.slug} ${n.servingLabel} ${n.kcalLow}-${n.kcalHigh}`).toBeLessThanOrEqual(mid * 0.2 + 1);
      }
    }
  });

  it("INDB names: a one-word spelling is the dish's other spelling, one word before a dish its ingredient; a seeded slug never changes (beta 3.9)", () => {
    expect(indbNames('Potato pakora/pakoda (Aloo pakoda)')).toEqual({ name: 'Potato pakora', slugName: 'Potato pakora', aliases: ['Aloo pakoda'], spellings: ['Potato pakoda'] });
    expect(indbNames('Ghiya/Lauki Kofta Curry')).toEqual({ name: 'Lauki Kofta Curry', slugName: 'Ghiya', aliases: [], spellings: [] });
    expect(indbNames('Chapati/Roti')).toEqual({ name: 'Chapati', slugName: 'Chapati', aliases: ['Roti'], spellings: [] });
    // A spelling never makes a recipe "one FITOS already has": the pakoras are foods, not skipped for "pakoda".
    expect(bySlug.get('potato-pakora')?.aliases).toEqual(['aloo pakoda', 'potato pakoda']);
    expect(bySlug.get('saunth')?.name).toBe('Sonth chutney with ginger');
    expect(bySlug.get('ghiya')?.name).toBe('Lauki Kofta Curry');
  });

  it('plain milk and paneer are foods now (backlog E24)', () => {
    expect(bySlug.get('paneer')).toMatchObject({ source: 'ifct', name: 'Paneer' });
    expect(bySlug.get('milk-whole-cow')).toMatchObject({ source: 'ifct' });
    expect(bySlug.get('milk-whole-buffalo')).toMatchObject({ source: 'ifct' });
    expect(bySlug.get('milk-semi-skimmed')?.aliases).toContain('double toned milk');
  });
});

describe('deep-fried INDB recipes (beta 3.9, ADR-036 amendment)', () => {
  const ref = new Map(cofid.foods.map((f) => [f.code, f]));

  it("the owner's check: one share per kind puts every CoFID reference's energy within +-15 %", () => {
    for (const k of FRIED_KINDS) {
      expect(k.references.length, k.kind).toBeGreaterThan(0);
      for (const code of k.references) {
        const c = ref.get(code)!;
        const measured = 4 * (c.protein + c.carb) + 9 * c.fat;
        const byShare = (4 + 9 * k.share) * (c.protein + c.carb);
        expect(Math.abs(byShare / measured - 1), `${k.kind} vs ${code} ${c.name}`).toBeLessThanOrEqual(0.15);
      }
    }
  });

  it("the references are exactly cofid-picks.json's oilReferences, converted, and never foods themselves", () => {
    const codes = [...new Set(FRIED_KINDS.flatMap((k) => k.references))].sort();
    expect(codes).toEqual([...cofidPicks.oilReferences].sort());
    for (const code of codes) expect(ref.has(code), code).toBe(true);
    const asFoods = new Set([...cofidPicks.replace.map((r) => r.code), ...cofidPicks.foods.map((f) => f.code)]);
    for (const code of codes) {
      expect(asFoods.has(code), code).toBe(false);
      expect(foods.some((f) => f.sourceRef.startsWith(`UK CoFID 2021 · ${code}`)), code).toBe(false);
    }
  });

  it('the pan comes out: a poori is ~110 kcal, not ~920; samosa, vada and cutlet stay out', () => {
    expect(bySlug.get('methi-poori')?.nutrition[0]).toMatchObject({ servingLabel: '1 poori', kcalLow: 90, kcalHigh: 123, fatLow: 5.3, fatHigh: 7.2 });
    expect(bySlug.get('cauliflower-pakora')?.sourceRef).toMatch(/fried \(cauliflower pakora\)/);
    for (const code of ['ASC361', 'BFP431', 'BFP437', 'ASC366']) {
      expect(manifest.indbSkipped.find((s) => s.code === code)?.reason, code).toMatch(/^deep-fried/);
    }
    // No fried food keeps a pan's worth of oil (INDB's pakora plate held 485 g).
    for (const e of manifest.indbFoods.filter((x) => x.fried !== null)) {
      const n = bySlug.get(e.slug)!.nutrition[0]!;
      expect(n.fatHigh, e.slug).toBeLessThan(60);
    }
  });
});
