/**
 * Builds database/seeds/foods.json and foods.manifest.json from the three
 * committed input files and the two permitted USDA downloads (Phase 7).
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
} as const;
const texts = {
  usdaPicks: readFileSync(`${FOOD_SOURCES_DIR}usda-picks.json`, 'utf8'),
  carried: readFileSync(`${FOOD_SOURCES_DIR}carried.json`, 'utf8'),
  recipes: readFileSync(`${FOOD_SOURCES_DIR}recipes.json`, 'utf8'),
};
const picks = usdaPicksFileSchema.parse(JSON.parse(texts.usdaPicks));
const carried = carriedFileSchema.parse(JSON.parse(texts.carried));
const recipes = recipesFileSchema.parse(JSON.parse(texts.recipes));

const { foods, manifest } = buildFoodSeed({ picks, carried, recipes, usda: loadUsda(usdaDir) });

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
  },
  seed: { file: 'database/seeds/foods.json', sha256: sha256(seedText) },
  counts: manifest.counts,
  rules: manifest.rules,
  usdaFoods: manifest.usdaFoods,
  droppedPicks: manifest.droppedPicks,
  carriedFoods: manifest.carriedFoods,
  compositeFoods: manifest.compositeFoods,
  compositeInputs: manifest.compositeInputs,
});
const manifestText = serialise(full);

const c = full.counts;
const summary = `${c.total} foods — ${c.usda} USDA, ${c.estimatedCarried} carried estimates, ${c.estimatedComposite} composite estimates; ${c.usdaPicksDropped} USDA picks dropped; gap to ~${c.targetApprox}: ${c.gapToTarget}`;

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
