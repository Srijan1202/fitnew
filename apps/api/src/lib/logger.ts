/**
 * pino logger. Redaction is not optional: §24 requires that email, tokens and
 * health values never reach the log sink.
 */
import type { LoggerOptions } from 'pino';

export function loggerOptions(level: string, pretty: boolean): LoggerOptions {
  return {
    level,
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        'email',
        '*.email',
        'token',
        '*.token',
        'weight',
        '*.weight',
        'weightKg',
        '*.weightKg',
        'photo_path',
        '*.photo_path',
      ],
      censor: '[redacted]',
    },
    ...(pretty
      ? { transport: { target: 'pino-pretty', options: { translateTime: 'HH:MM:ss', ignore: 'pid,hostname' } } }
      : {}),
  };
}
