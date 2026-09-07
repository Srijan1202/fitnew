/**
 * Single exit point for every error. Produces the §10 envelope and nothing else.
 *
 * Two rules that matter: an unexpected error never leaks its message to the
 * client (it goes to the log instead), and every response carries the requestId
 * so a user-reported failure can be found in Cloud Logging.
 */
import fp from 'fastify-plugin';
import type { FastifyInstance } from 'fastify';
import { ZodError } from 'zod';

import { AppError, HTTP_STATUS_FOR_CODE, type ErrorCode } from '../lib/errors.js';

function envelope(
  code: ErrorCode,
  message: string,
  requestId: string,
  details?: readonly { path: string; issue: string }[],
): Record<string, unknown> {
  return {
    error: {
      code,
      message,
      ...(details !== undefined && details.length > 0 ? { details } : {}),
      requestId,
    },
  };
}

export default fp(
  async function errorHandlerPlugin(app: FastifyInstance) {
    app.setNotFoundHandler((request, reply) => {
      void reply
        .status(404)
        .send(envelope('NOT_FOUND', `Route ${request.method} ${request.url} does not exist.`, request.id));
    });

    app.setErrorHandler((error, request, reply) => {
      if (error instanceof AppError) {
        request.log.warn({ code: error.code }, error.message);
        void reply.status(error.statusCode).send(
          envelope(error.code, error.message, request.id, error.details),
        );
        return;
      }

      if (error instanceof ZodError) {
        const details = error.issues.map((issue) => ({
          path: issue.path.join('.'),
          issue: issue.message,
        }));
        void reply
          .status(HTTP_STATUS_FOR_CODE.VALIDATION_FAILED)
          .send(envelope('VALIDATION_FAILED', 'Request failed validation.', request.id, details));
        return;
      }

      if (error.statusCode === 429) {
        void reply
          .status(429)
          .send(envelope('RATE_LIMITED', 'Too many requests. Slow down and retry.', request.id));
        return;
      }

      // Unexpected: log it in full, tell the client nothing useful to an attacker.
      request.log.error({ err: error }, 'Unhandled error');
      void reply
        .status(500)
        .send(envelope('INTERNAL', 'Something went wrong on our side.', request.id));
    });
  },
  { name: 'error-handler' },
);
