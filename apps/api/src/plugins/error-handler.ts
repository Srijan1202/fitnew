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
import {
  hasZodFastifySchemaValidationErrors,
  isResponseSerializationError,
} from 'fastify-type-provider-zod';

import { isDatabaseUnavailable } from '../db/errors.js';
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

      // Request validation. Fastify wraps the Zod failure as FST_ERR_VALIDATION
      // (statusCode 400) with the original issues under `validation[].params.issue`;
      // a bare ZodError only reaches here if a handler parses manually.
      if (hasZodFastifySchemaValidationErrors(error)) {
        const details = error.validation.map((v) => ({
          path: v.params.issue.path.join('.'),
          issue: v.params.issue.message,
        }));
        void reply
          .status(HTTP_STATUS_FOR_CODE.VALIDATION_FAILED)
          .send(envelope('VALIDATION_FAILED', 'Request failed validation.', request.id, details));
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

      // Response serialization: OUR bug, never the client's. 500, logged loudly
      // with the schema path so it is findable, message kept generic.
      if (isResponseSerializationError(error)) {
        request.log.error({ err: error, path: error.cause }, 'Response failed its own schema');
        void reply
          .status(500)
          .send(envelope('INTERNAL', 'Something went wrong on our side.', request.id));
        return;
      }

      // Fastify's own client-side rejections — an unparseable or empty JSON
      // body (FST_ERR_CTP_*), a body over the limit, an unsupported media
      // type. The request was malformed, so it is the client's 4xx, not a
      // 500 that pages someone. Found by Dio sending `Content-Type:
      // application/json` with no body on POST /onboarding/complete.
      if (typeof error.statusCode === 'number' && error.statusCode >= 400 && error.statusCode < 500 && error.statusCode !== 429) {
        request.log.warn({ code: error.code }, error.message);
        void reply
          .status(HTTP_STATUS_FOR_CODE.VALIDATION_FAILED)
          .send(envelope('VALIDATION_FAILED', 'Request could not be read.', request.id, [
            { path: 'body', issue: error.message },
          ]));
        return;
      }

      if (error.statusCode === 429) {
        void reply
          .status(429)
          .send(envelope('RATE_LIMITED', 'Too many requests. Slow down and retry.', request.id));
        return;
      }

      // The database is unreachable (Phase 6.7): temporary, not our bug. 503
      // tells the phone to wait and retry instead of counting a failure.
      if (isDatabaseUnavailable(error)) {
        request.log.error({ err: error }, 'Database unavailable');
        void reply
          .status(HTTP_STATUS_FOR_CODE.UPSTREAM_UNAVAILABLE)
          .send(envelope('UPSTREAM_UNAVAILABLE', 'FITOS is temporarily unavailable. Try again shortly.', request.id));
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
