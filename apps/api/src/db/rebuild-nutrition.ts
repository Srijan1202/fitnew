/**
 * Rebuild the `daily_nutrition` cache from the live food-log item snapshots
 * for every user (§9.4: caches must be rebuildable by a script). Idempotent;
 * the result equals what the transactional updates maintain.
 *
 *   pnpm --filter @fitos/api db:rebuild-nutrition
 */
import { createDatabase } from './client.js';
import { rebuildDailyNutrition } from '../modules/nutrition/log-repository.js';

export async function rebuildNutrition(connectionString: string, log: (line: string) => void = () => undefined): Promise<number> {
  const handle = createDatabase(connectionString);
  try {
    const { days } = await rebuildDailyNutrition(handle.db);
    log(`rebuilt ${days} user-day(s) of daily_nutrition`);
    return days;
  } finally {
    await handle.client.end({ timeout: 5 });
  }
}

const invokedDirectly = process.argv[1]?.endsWith('rebuild-nutrition.ts') === true || process.argv[1]?.endsWith('rebuild-nutrition.js') === true;
if (invokedDirectly) {
  const url = process.env['DATABASE_URL'];
  if (url === undefined) {
    console.error('DATABASE_URL is required');
    process.exit(1);
  }
  rebuildNutrition(url, console.log).catch((error: unknown) => {
    console.error(error);
    process.exit(1);
  });
}
