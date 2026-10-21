/**
 * pino logger. Redaction is not optional: §24 requires that email, tokens and
 * health values never reach the log sink.
 *
 * Phase 17 (ADR-023 D5): request URLs are logged with sensitive query values
 * masked (`/admin/users?email=…` is a support lookup), and more fields are
 * redacted (passwords, ID tokens, API keys). A test reads the real log output.
 */
import type { LoggerOptions } from 'pino';

/** Query parameters whose values never reach the log. */
const SENSITIVE_QUERY = new Set(['email', 'token', 'id_token', 'idtoken', 'key', 'apikey', 'password']);

/** A URL with its sensitive query values replaced, everything else kept. */
export function redactUrl(url: string): string {
  const q = url.indexOf('?');
  if (q < 0) return url;
  const params = url
    .slice(q + 1)
    .split('&')
    .map((pair) => {
      const eq = pair.indexOf('=');
      const name = decodeURIComponent((eq < 0 ? pair : pair.slice(0, eq)).replace(/\+/g, ' ')).toLowerCase();
      return SENSITIVE_QUERY.has(name) && eq >= 0 ? `${pair.slice(0, eq)}=[redacted]` : pair;
    });
  return `${url.slice(0, q)}?${params.join('&')}`;
}

export function loggerOptions(level: string, pretty: boolean): LoggerOptions {
  return {
    level,
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        'req.headers["x-goog-api-key"]',
        'email',
        '*.email',
        'token',
        '*.token',
        'idToken',
        '*.idToken',
        'password',
        '*.password',
        'apiKey',
        '*.apiKey',
        'weight',
        '*.weight',
        'weightKg',
        '*.weightKg',
        'photo_path',
        '*.photo_path',
      ],
      censor: '[redacted]',
    },
    serializers: {
      // Fastify's request line, with the URL's sensitive query values masked.
      req: (req: { method?: string; url?: string; hostname?: string; ip?: string; socket?: { remotePort?: number } }) => ({
        method: req.method,
        url: typeof req.url === 'string' ? redactUrl(req.url) : req.url,
        hostname: req.hostname,
        remoteAddress: req.ip,
        remotePort: req.socket?.remotePort,
      }),
    },
    ...(pretty
      ? { transport: { target: 'pino-pretty', options: { translateTime: 'HH:MM:ss', ignore: 'pid,hostname' } } }
      : {}),
  };
}
