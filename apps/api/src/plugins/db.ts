/**
 * Decorates the Fastify instance with the database handle and closes the pool
 * on shutdown. Routes never import the client directly; they read `app.database`.
 *
 * `handle` may be supplied directly so tests can exercise the health route
 * against a stub connection. Production always passes a connection string.
 */
import fp from 'fastify-plugin';
import type { FastifyInstance } from 'fastify';

import { createDatabase, type DatabaseHandle } from '../db/client.js';

declare module 'fastify' {
  interface FastifyInstance {
    database: DatabaseHandle;
  }
}

export interface DbPluginOptions {
  readonly connectionString?: string;
  readonly handle?: DatabaseHandle;
}

export default fp(
  async function dbPlugin(app: FastifyInstance, opts: DbPluginOptions) {
    const handle =
      opts.handle ??
      (opts.connectionString !== undefined
        ? createDatabase(opts.connectionString)
        : undefined);

    if (handle === undefined) {
      throw new Error('dbPlugin requires either a connectionString or a handle');
    }

    app.decorate('database', handle);

    app.addHook('onClose', async () => {
      await handle.client.end({ timeout: 5 });
    });
  },
  { name: 'db' },
);
