/**
 * Runs in every worker before its tests: the same derivation as the global
 * setup, so `TEST_DATABASE_URL` is set whether or not the worker inherited
 * the global setup's environment.
 */
import { loadDotEnv, resolveTestDatabaseUrl } from './test-database.js';

loadDotEnv();
const url = resolveTestDatabaseUrl();
if (url !== undefined) process.env['TEST_DATABASE_URL'] = url;
