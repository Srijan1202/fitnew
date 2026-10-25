/**
 * Builds database/seeds/foods.json and foods.manifest.json from the
 * committed input files and the two permitted USDA downloads (Phase 7).
 * Beta 3.7 (ADR-036): plus the converted IFCT 2017, INDB 2024 and CoFID 2021
 * files (database/seeds/food-sources/tools/convert_sources.py makes them
 * from their downloads; the downloads' checksums are in each file).
 *
 *   pnpm --filter @fitos/api food-seed:build -- --usda-dir <dir>          write
 *   pnpm --filter @fitos/api food-seed:build -- --usda-dir <dir> --check  verify only
 *
 * <dir> holds the downloaded zips from https://fdc.nal.usda.gov/download-datasets/
 * AND their unzipped JSON (see USDA_DATASETS for the exact file names). The
 * raw files are never committed. Output is byte-for-byte reproducible: the
 * same inputs always give the same two files, and --check proves it.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

import { buildFoodSeed } from '../db/food-seed/build.js';
import {
  FOOD_MANIFEST_FILE,
  FOOD_SEED_FILE,
  FOOD_SOURCES_DIR,
  USDA_CITATION,
  USDA_DATASETS,
  USDA_LICENSE,
  carriedFileSchema,
  cofidFileSchema,
  cofidPicksFileSchema,
  ifctFileSchema,
  indbFileSchema,
  manifestSchema,
  recipesFileSchema,
  serialise,
  sha256,
  usdaPicksFileSchema,
  type FoodSeedManifest,
  type UsdaDatasetKey,
} from '../db/food-seed/format.js';
import { loadUsda } from '../db/food-seed/usda.js';
import { createHash } from 'node:crypto';

function argument(name: string): string | undefined {
  const i = process.argv.indexOf(name);
  return i === -1 ? undefined : process.argv[i + 1];
}

const usdaDir = argument('--usda-dir') ?? process.env['FITOS_USDA_DIR'];
if (usdaDir === undefined || usdaDir === '') {
  console.error('usage: build-food-seed --usda-dir <dir with the USDA downloads> [--check]');
  process.exit(2);
}
const check = process.argv.includes('--check');

const inputFiles = {
  usdaPicks: 'database/seeds/food-sources/usda-picks.json',
  carried: 'database/seeds/food-sources/carried.json',
  recipes: 'database/seeds/food-sources/recipes.json',
  ifct: 'database/seeds/food-sources/ifct2017.json',
  indb: 'database/seeds/food-sources/indb.json',
  cofid: 'database/seeds/food-sources/cofid.json',
  cofidPicks: 'database/seeds/food-sources/cofid-picks.json',
} as const;
const texts = {
  usdaPicks: readFileSync(`${FOOD_SOURCES_DIR}usda-picks.json`, 'utf8'),
  carried: readFileSync(`${FOOD_SOURCES_DIR}carried.json`, 'utf8'),
  recipes: readFileSync(`${FOOD_SOURCES_DIR}recipes.json`, 'utf8'),
  ifct: readFileSync(`${FOOD_SOURCES_DIR}ifct2017.json`, 'utf8'),
  indb: readFileSync(`${FOOD_SOURCES_DIR}indb.json`, 'utf8'),
  cofid: readFileSync(`${FOOD_SOURCES_DIR}cofid.json`, 'utf8'),
  cofidPicks: readFileSync(`${FOOD_SOURCES_DIR}cofid-picks.json`, 'utf8'),
};
const picks = usdaPicksFileSchema.parse(JSON.parse(texts.usdaPicks));
const carried = carriedFileSchema.parse(JSON.parse(texts.carried));
const recipes = recipesFileSchema.parse(JSON.parse(texts.recipes));
const ifct = ifctFileSchema.parse(JSON.parse(texts.ifct));
const indb = indbFileSchema.parse(JSON.parse(texts.indb));
const cofid = cofidFileSchema.parse(JSON.parse(texts.cofid));
const cofidPicks = cofidPicksFileSchema.parse(JSON.parse(texts.cofidPicks));

const { foods, manifest } = buildFoodSeed({ picks, carried, recipes, usda: loadUsda(usdaDir), ifct, indb, cofid, cofidPicks });

const seedText = serialise(foods);
const datasets: FoodSeedManifest['datasets'] = (Object.keys(USDA_DATASETS) as UsdaDatasetKey[]).map((key) => {
  const meta = USDA_DATASETS[key];
  return {
    key,
    name: meta.name,
    release: meta.release,
    releaseDate: meta.release,
    file: meta.file,
    sha256: createHash('sha256').update(readFileSync(join(usdaDir, meta.file))).digest('hex'),
    license: USDA_LICENSE,
    citation: USDA_CITATION,
  };
});
// Beta 3.7: the measured sources, by their downloads' checksums (recorded in the converted files).
const measured = [
  { key: 'ifct2017' as const, file: ifct, name: 'Indian Food Composition Tables 2017 (NIN-ICMR)', release: '2017' },
  { key: 'indb' as const, file: indb, name: 'Indian Nutrient Databank (INDB)', release: '2024' },
  { key: 'cofid2021' as const, file: cofid, name: "McCance and Widdowson's Composition of Foods Integrated Dataset", release: '2021' },
];
for (const m of measured) {
  for (const r of m.file.raw) {
    datasets.push({ key: m.key, name: m.name, release: m.release, releaseDate: m.release, file: r.file, sha256: r.sha256, license: m.file.terms, citation: m.file.citation });
  }
}
const full: FoodSeedManifest = manifestSchema.parse({
  manifestVersion: manifest.manifestVersion,
  builderVersion: manifest.builderVersion,
  builder: manifest.builder,
  datasets,
  excludedSources: manifest.excludedSources,
  inputs: {
    usdaPicks: { file: inputFiles.usdaPicks, version: picks.version, sha256: sha256(texts.usdaPicks) },
    carried: { file: inputFiles.carried, version: carried.version, sha256: sha256(texts.carried) },
    recipes: { file: inputFiles.recipes, version: recipes.version, sha256: sha256(texts.recipes) },
    ifct: { file: inputFiles.ifct, version: ifct.version, sha256: sha256(texts.ifct) },
    indb: { file: inputFiles.indb, version: indb.version, sha256: sha256(texts.indb) },
    cofid: { file: inputFiles.cofid, version: cofid.version, sha256: sha256(texts.cofid) },
    cofidPicks: { file: inputFiles.cofidPicks, version: cofidPicks.version, sha256: sha256(texts.cofidPicks) },
  },
  seed: { file: 'database/seeds/foods.json', sha256: sha256(seedText) },
  counts: manifest.counts,
  rules: manifest.rules,
  usdaFoods: manifest.usdaFoods,
  droppedPicks: manifest.droppedPicks,
  carriedFoods: manifest.carriedFoods,
  compositeFoods: manifest.compositeFoods,
  ifctFoods: manifest.ifctFoods,
  ifctSkipped: manifest.ifctSkipped,
  indbFoods: manifest.indbFoods,
  indbSkipped: manifest.indbSkipped,
  cofidFoods: manifest.cofidFoods,
  compositeInputs: manifest.compositeInputs,
});
const manifestText = serialise(full);

const c = full.counts;
const summary =
  `${c.total} foods — ${c.usda} USDA, ${c.ifct} IFCT (${c.ifctSkipped} skipped), ${c.indb} INDB (${c.indbSkipped} skipped), ${c.cofidNew} CoFID (+${c.cofidReplaced} replacing composites), ` +
  `${c.estimatedCarried} carried estimates, ${c.estimatedComposite - c.cofidReplaced} composite estimates; ${c.usdaPicksDropped} USDA picks dropped; gap to ~${c.targetApprox}: ${c.gapToTarget}`;

if (check) {
  const same = (file: string, text: string): boolean => {
    try {
      return readFileSync(file, 'utf8') === text;
    } catch {
      return false;
    }
  };
  const seedSame = same(FOOD_SEED_FILE, seedText);
  const manifestSame = same(FOOD_MANIFEST_FILE, manifestText);
  console.log(`check: foods.json ${seedSame ? 'identical' : 'DIFFERS'}, foods.manifest.json ${manifestSame ? 'identical' : 'DIFFERS'}`);
  console.log(summary);
  process.exit(seedSame && manifestSame ? 0 : 1);
}

writeFileSync(FOOD_SEED_FILE, seedText);
writeFileSync(FOOD_MANIFEST_FILE, manifestText);
console.log(`wrote foods.json (${seedText.length} bytes, sha256 ${full.seed.sha256.slice(0, 12)}…) and foods.manifest.json`);
console.log(summary);
for (const d of full.droppedPicks) console.log(`  dropped ${d.slug} (FDC ${d.fdcId}): ${d.reason}`);
