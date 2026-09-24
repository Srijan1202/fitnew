/**
 * Development-only in-process mirror timer (Phase 9, owner D1): runs the
 * MessIT mirror shortly after boot and then every N hours, so a LAN build
 * has current menus without a scheduler. Off in production and staging by
 * default — hosted, the trigger is Cloud Scheduler (deferred, GCP paused).
 * Overlap with a manual job is harmless: runs take an advisory lock.
 */
import type { FastifyInstance } from 'fastify';

import type { Env } from '../../lib/env.js';
import { runMirror } from './mirror.js';

export const BOOT_DELAY_MS = 5_000;

/** Hours between runs; 0 = off. Default: 12 in development, off elsewhere. */
export function mirrorIntervalHours(env: Pick<Env, 'NODE_ENV' | 'MESS_MIRROR_INTERVAL_HOURS'>): number {
  if (env.MESS_MIRROR_INTERVAL_HOURS !== undefined) return env.MESS_MIRROR_INTERVAL_HOURS;
  return env.NODE_ENV === 'development' ? 12 : 0;
}

export function startMirrorTimer(app: FastifyInstance, env: Env): () => void {
  const hours = mirrorIntervalHours(env);
  if (hours <= 0) return () => undefined;
  const run = (): void => {
    runMirror(app.database).then(
      (report) => app.log.info({ mirror: report }, 'mess mirror run'),
      (error: unknown) => app.log.warn({ err: error }, 'mess mirror run failed'),
    );
  };
  const boot = setTimeout(run, BOOT_DELAY_MS);
  const every = setInterval(run, hours * 3_600_000);
  boot.unref();
  every.unref();
  app.log.info({ hours }, 'mess mirror timer on (development)');
  return () => {
    clearTimeout(boot);
    clearInterval(every);
  };
}
