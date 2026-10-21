/**
 * §24 / Phase 17: redaction verified in the real log output — a Fastify
 * instance with the production logger options, writing to a captured stream.
 */
import Fastify from 'fastify';
import { describe, expect, it } from 'vitest';

import { loggerOptions, redactUrl } from './logger.js';

describe('log redaction (§24)', () => {
  it('URLs keep their path and harmless query, and lose sensitive values', () => {
    expect(redactUrl('/v1/admin/users?email=srijan%40vit.ac.in')).toBe('/v1/admin/users?email=[redacted]');
    expect(redactUrl('/v1/x?q=dal&Token=abc&limit=5')).toBe('/v1/x?q=dal&Token=[redacted]&limit=5');
    expect(redactUrl('/v1/nutrition/foods/search?q=paneer')).toBe('/v1/nutrition/foods/search?q=paneer');
    expect(redactUrl('/health')).toBe('/health');
  });

  it('what reaches the log sink: no email, token, authorization, password, key or weight', async () => {
    const lines: string[] = [];
    const app = Fastify({ logger: { ...loggerOptions('info', false), stream: { write: (l: string) => lines.push(l) } } });
    app.get('/v1/admin/users', async (request) => {
      request.log.info(
        { email: 'student@vit.ac.in', weightKg: 71.4, token: 'tok-123', body: { password: 'hunter2', idToken: 'eyJhbG', apiKey: 'AIzaSECRET' } },
        'lookup',
      );
      return { ok: true };
    });
    await app.ready();
    const r = await app.inject({
      method: 'GET',
      url: '/v1/admin/users?email=student%40vit.ac.in&token=tok-456',
      headers: { authorization: 'Bearer eyJsecret', cookie: 'sid=1', 'x-goog-api-key': 'AIzaHEADER' },
    });
    expect(r.statusCode).toBe(200);
    await app.close();
    const out = lines.join('\n');
    expect(out).toContain('/v1/admin/users?email=[redacted]&token=[redacted]');
    expect(out).toContain('"lookup"');
    for (const secret of ['student@vit.ac.in', 'student%40vit.ac.in', '71.4', 'tok-123', 'tok-456', 'hunter2', 'eyJhbG', 'eyJsecret', 'AIzaSECRET', 'AIzaHEADER', 'sid=1']) {
      expect(out, secret).not.toContain(secret);
    }
  });
});
