/**
 * Process entrypoint. Binds the port and handles orderly shutdown.
 *
 * Cloud Run sends SIGTERM before it removes an instance; draining in-flight
 * requests and closing the pool avoids a burst of connection errors on deploy.
 */
import { buildApp } from './app.js';
import { loadEnv } from './lib/env.js';
import { serve } from './serve.js';

async function main(): Promise<void> {
  const env = loadEnv();
  const app = await buildApp(env);

  for (const signal of ['SIGTERM', 'SIGINT'] as const) {
    process.once(signal, () => {
      app.log.info({ signal }, 'Shutting down');
      void app.close().then(
        () => process.exit(0),
        (error: unknown) => {
          app.log.error({ err: error }, 'Shutdown failed');
          process.exit(1);
        },
      );
    });
  }

  // The mess mirror timer (development only by default), then the port.
  await serve(app, env);
}

main().catch((error: unknown) => {
  console.error('Failed to start API:', error);
  process.exit(1);
});
