/**
 * Rebuild the `muscle_volume_weekly` cache from set_logs for every user
 * (§9.4: caches must be rebuildable by a script). Idempotent.
 *
 *   pnpm --filter @fitos/api db:rebuild-volume
 */
import { createDatabase } from './client.js';
import { users } from './schema.js';
import { TrainingRepository } from '../modules/training/repository.js';
import { ProgressionAssembler, VOLUME_WEEKS, localDate } from '../modules/workout/progression.js';
import { WorkoutRepository } from '../modules/workout/repository.js';
import { recentWeeks } from '@fitos/core/training/volume';

export async function rebuildVolume(connectionString: string, log: (line: string) => void = () => undefined): Promise<number> {
  const handle = createDatabase(connectionString);
  try {
    const repo = new WorkoutRepository(handle.db);
    const assembler = new ProgressionAssembler(repo, new TrainingRepository(handle.db));
    const rows = await handle.db.select({ id: users.id, timezone: users.timezone }).from(users);
    let written = 0;
    for (const u of rows) {
      const today = localDate(new Date(), u.timezone);
      const sets = await assembler.volumeSets(u.id, today, u.timezone);
      for (const week of recentWeeks(today, VOLUME_WEEKS)) {
        await assembler.cacheWeek(u.id, week, sets);
        written += 1;
      }
    }
    log(`rebuilt ${written} user-weeks for ${rows.length} user(s)`);
    return written;
  } finally {
    await handle.client.end({ timeout: 5 });
  }
}

const invokedDirectly = process.argv[1]?.endsWith('rebuild-volume.ts') === true || process.argv[1]?.endsWith('rebuild-volume.js') === true;
if (invokedDirectly) {
  const url = process.env['DATABASE_URL'];
  if (url === undefined) {
    console.error('DATABASE_URL is required');
    process.exit(1);
  }
  rebuildVolume(url, console.log).catch((error: unknown) => {
    console.error(error);
    process.exit(1);
  });
}
