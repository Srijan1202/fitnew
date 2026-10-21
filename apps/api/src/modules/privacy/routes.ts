/**
 * Privacy — Phase 17 (MASTER-SPEC §23, §10.1; ADR-023): consents,
 * `POST /user/export`, `DELETE /user`. Default-deny like every /v1 route;
 * export and deletion have tight per-user limits of their own.
 */
import type { FastifyInstance, FastifyRequest } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import {
  consentsResponseSchema,
  deleteAccountRequestSchema,
  deleteAccountResponseSchema,
  errorEnvelopeSchema,
  exportResponseSchema,
  setConsentRequestSchema,
} from '@fitos/contracts';

import { AppError } from '../../lib/errors.js';
import { PrivacyRepository } from './repository.js';
import { PrivacyService } from './service.js';

function requireUserId(userId: string | null): string {
  if (userId === null) throw new AppError('UNAUTHENTICATED', 'Create a session first (POST /auth/session).');
  return userId;
}

const perUser = (max: number) =>
  ({
    max,
    timeWindow: '1 hour',
    hook: 'preHandler',
    keyGenerator: (request: FastifyRequest): string => (request.userId !== null ? `privacy:${request.userId}` : `privacy-ip:${request.ip}`),
  }) as const;

/** §24: stricter on the routes that move or destroy everything. */
export const EXPORT_PER_HOUR = 3;
export const DELETE_PER_HOUR = 5;

export async function privacyRoutes(app: FastifyInstance, opts: { ipSalt: string }): Promise<void> {
  const service = new PrivacyService(new PrivacyRepository(app.database.db), app.accountDeleter, app.log);
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 404: errorEnvelopeSchema, 422: errorEnvelopeSchema, 429: errorEnvelopeSchema };
  const tags = ['privacy'];

  typed.get('/user/consents', {
    schema: { summary: 'My consent per purpose, and whether the privacy policy changed since', tags, security, response: { 200: consentsResponseSchema, ...errors } },
  }, async (request) => service.consents(requireUserId(request.userId)));

  typed.post('/user/consents', {
    schema: {
      summary: 'Grant or withdraw one purpose (FITOS AI is optional and revocable; the required ones can only be re-granted)',
      tags,
      security,
      body: setConsentRequestSchema,
      response: { 200: consentsResponseSchema, ...errors },
    },
  }, async (request) => service.setConsent(requireUserId(request.userId), request.body.type, request.body.granted, { ip: request.ip, ipSalt: opts.ipSalt }));

  typed.post('/user/export', {
    config: { rateLimit: perUser(EXPORT_PER_HOUR) },
    schema: {
      summary: 'Everything FITOS holds about me, as machine-readable JSON (§23.4)',
      tags,
      security,
      response: { 200: exportResponseSchema, ...errors },
    },
  }, async (request, reply) => {
    const body = await service.export(requireUserId(request.userId));
    void reply.header('content-disposition', `attachment; filename="fitos-export-${body.exportedAt.slice(0, 10)}.json"`);
    return body;
  });

  typed.delete('/user', {
    config: { rateLimit: perUser(DELETE_PER_HOUR) },
    schema: {
      summary: 'Delete my account and every row of my data, now (§23.3). Send {"confirm":"DELETE"}.',
      tags,
      security,
      body: deleteAccountRequestSchema,
      response: { 200: deleteAccountResponseSchema, ...errors },
    },
  }, async (request) => service.deleteAccount(requireUserId(request.userId)));
}
