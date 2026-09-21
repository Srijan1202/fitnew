/** Runs once before the workers start: pick the test database and make sure it exists. */
import { ensureTestDatabase, loadDotEnv, resolveTestDatabaseUrl } from './test-database.js';

export default async function setup(): Promise<void> {
  loadDotEnv();
  const url = resolveTestDatabaseUrl();
  if (url === undefined) return;
  await ensureTestDatabase(url);
  process.env['TEST_DATABASE_URL'] = url;
}
