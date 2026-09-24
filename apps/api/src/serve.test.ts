import { afterEach, describe, expect, it } from 'vitest';

import { serve } from './serve.js';
import { mirrorIntervalHours } from './modules/mess/mirror-timer.js';
import { buildStubApp, testEnv } from './test/build-test-app.js';

describe('serve (Phase 9 boot order)', () => {
  const apps: { close: () => Promise<unknown> }[] = [];
  afterEach(async () => {
    while (apps.length > 0) await apps.pop()?.close();
  });

  it('boots in development with the mirror timer on, and shuts down cleanly', async () => {
    const { app } = await buildStubApp();
    apps.push(app);
    await expect(serve(app, testEnv({ NODE_ENV: 'development' }), 0)).resolves.toBeUndefined();
    const r = await app.inject({ method: 'GET', url: '/livez' });
    expect(r.statusCode).toBe(200);
  });

  it('boots in production with the timer off', async () => {
    const { app } = await buildStubApp();
    apps.push(app);
    await expect(serve(app, testEnv({ NODE_ENV: 'production' }), 0)).resolves.toBeUndefined();
  });

  it('the timer: 12 h in development, off elsewhere, overridable', () => {
    expect(mirrorIntervalHours({ NODE_ENV: 'development', MESS_MIRROR_INTERVAL_HOURS: undefined })).toBe(12);
    expect(mirrorIntervalHours({ NODE_ENV: 'production', MESS_MIRROR_INTERVAL_HOURS: undefined })).toBe(0);
    expect(mirrorIntervalHours({ NODE_ENV: 'test', MESS_MIRROR_INTERVAL_HOURS: undefined })).toBe(0);
    expect(mirrorIntervalHours({ NODE_ENV: 'production', MESS_MIRROR_INTERVAL_HOURS: 12 })).toBe(12);
    expect(mirrorIntervalHours({ NODE_ENV: 'development', MESS_MIRROR_INTERVAL_HOURS: 0 })).toBe(0);
  });
});
