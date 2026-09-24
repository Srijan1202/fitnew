/**
 * Starts a built app: the development-only mess mirror timer (Phase 9), then
 * the port. Separate from server.ts so the boot order is testable — every
 * hook must be registered before `listen()`, which Fastify enforces (the
 * Phase 9 timer's first version added its onClose hook after listen and the
 * development server crash-looped).
 */
import type { FastifyInstance } from 'fastify';

import type { Env } from './lib/env.js';
import { startMirrorTimer } from './modules/mess/mirror-timer.js';

export async function serve(app: FastifyInstance, env: Env, port = env.PORT): Promise<void> {
  const stopMirror = startMirrorTimer(app, env);
  app.addHook('onClose', async () => stopMirror());
  // 0.0.0.0 is required on Cloud Run; localhost-only would fail health checks.
  await app.listen({ port, host: '0.0.0.0' });
}
