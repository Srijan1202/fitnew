/**
 * The MessIT mirror as a one-shot job (Phase 9, owner D1).
 *
 *   pnpm --filter @fitos/api mess:mirror            (local, from source)
 *   node apps/api/dist/jobs/mirror-mess.js          (the image)
 *
 * This is the shape a Cloud Scheduler → Cloud Run job would run twice a day
 * (§14.6). That trigger is NOT set up: GCP work is paused (Gate 6.7-3), so
 * Cloud Scheduler is a deferred deployment dependency. Locally the API also
 * runs this on a 12-hour in-process timer (development only, server.ts).
 *
 * Exit code: 0 when at least one endpoint was fetched successfully (or
 * another run held the lock), 1 when every endpoint failed or the database
 * could not be reached. It prints a JSON report; nothing user-related.
 */
import { createDatabase } from '../db/client.js';
import { runMirror } from '../modules/mess/mirror.js';

const isDirectRun = process.argv[1] !== undefined && import.meta.url === new URL(`file://${process.argv[1]}`).href;

export async function mirrorJob(connectionString: string): Promise<number> {
  const handle = createDatabase(connectionString);
  try {
    const report = await runMirror(handle);
    console.log(JSON.stringify(report));
    if (!report.ran) return 0;
    const fetched = report.messes.filter((m) => m.outcome === 'new' || m.outcome === 'unchanged').length;
    return fetched > 0 ? 0 : 1;
  } finally {
    await handle.client.end({ timeout: 5 });
  }
}

if (isDirectRun) {
  const url = process.env['DATABASE_URL'];
  if (url === undefined || url === '') {
    console.error('DATABASE_URL is required');
    process.exit(1);
  }
  mirrorJob(url).then(
    (code) => process.exit(code),
    (error: unknown) => {
      console.error(error);
      process.exit(1);
    },
  );
}
