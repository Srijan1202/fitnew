/**
 * Dumps the generated OpenAPI 3.1 document to packages/contracts/openapi.json.
 *
 * The document is produced at runtime from the Zod schemas (§8.1), so this is
 * the artefact the Dart client will be generated from (§7.1) and the thing
 * that lets a PR review see a contract change as a diff.
 */
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import { buildApp } from '../app.js';
import type { Env } from '../lib/env.js';
import { FakeTokenVerifier } from '../test/fake-token-verifier.js';
import { stubDatabase } from '../test/build-test-app.js';

const env: Env = {
  NODE_ENV: 'test',
  PORT: 0,
  LOG_LEVEL: 'fatal',
  DATABASE_URL: 'postgres://unused:unused@localhost:5432/unused',
  FIREBASE_PROJECT_ID: 'openapi-export',
  CONSENT_IP_SALT: 'export-salt-not-secret',
  GEMINI_MODEL: 'gemini-3.6-flash',
  AI_TIMEOUT_MS: 5000,
  AI_MAX_OUTPUT_TOKENS: 512,
};

const out = fileURLToPath(new URL('../../../../packages/contracts/openapi.json', import.meta.url));

const app = await buildApp(env, { database: stubDatabase(), tokenVerifier: new FakeTokenVerifier() });
await app.ready();
writeFileSync(out, JSON.stringify(app.swagger(), null, 2) + '\n');
await app.close();
console.log(`wrote ${out}`);
