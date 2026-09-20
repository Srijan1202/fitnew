/**
 * Authentication plugin.
 *
 * DEFAULT-DENY under /v1. Every route beneath the versioned prefix requires a
 * valid Bearer ID token unless it opts out with `config: { public: true }`.
 * §10 lists exactly two unauthenticated surfaces — /health and /v1/meta/* —
 * so the safe default is "protected", and forgetting to mark a route leaves it
 * locked rather than open.
 *
 * Identity is derived from the verified token ONLY. Nothing here reads a
 * userId from the body, query or headers (§11, §24).
 */
import fp from 'fastify-plugin';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';

import { AppError } from '../lib/errors.js';
import { TokenVerificationError, type TokenVerifier, type VerifiedIdentity } from '../lib/token-verifier.js';

declare module 'fastify' {
  interface FastifyInstance {
    tokenVerifier: TokenVerifier;
  }
  interface FastifyRequest {
    /** Set by the auth hook on protected routes; null on public ones. */
    identity: VerifiedIdentity | null;
  }
  interface FastifyContextConfig {
    /** Opt a /v1 route out of authentication. Use sparingly; §10 names two. */
    public?: boolean;
  }
}

export const PROTECTED_PREFIX = '/v1';

function bearerToken(request: FastifyRequest): string | null {
  const header = request.headers.authorization;
  if (typeof header !== 'string') return null;
  const [scheme, token, ...rest] = header.trim().split(/\s+/);
  if (scheme?.toLowerCase() !== 'bearer' || token === undefined || rest.length > 0) return null;
  return token;
}

export function isProtectedRoute(url: string, config: { public?: boolean } | undefined): boolean {
  if (!url.startsWith(PROTECTED_PREFIX)) return false;
  return config?.public !== true;
}

/**
 * preHandler for admin-only routes (§11, §20). Runs AFTER the auth hook, so
 * `request.identity` is populated. A non-admin gets 403, not 404 — the route's
 * existence is not a secret, the data behind it is.
 */
export async function requireAdmin(request: FastifyRequest, _reply: FastifyReply): Promise<void> {
  if (request.identity === null) {
    throw new AppError('UNAUTHENTICATED', 'Sign in to continue.');
  }
  if (request.identity.claims['role'] !== 'admin') {
    throw new AppError('FORBIDDEN', 'This action requires an administrator.');
  }
}

export interface AuthPluginOptions {
  readonly verifier: TokenVerifier;
}

export default fp(
  async function authPlugin(app: FastifyInstance, opts: AuthPluginOptions) {
    app.decorate('tokenVerifier', opts.verifier);
    app.decorateRequest('identity', null);

    app.addHook('onRequest', async (request) => {
      request.identity = null;
      const { url, routeOptions } = request;
      if (!isProtectedRoute(routeOptions.url ?? url, routeOptions.config)) return;

      const token = bearerToken(request);
      if (token === null) {
        throw new AppError('UNAUTHENTICATED', 'Sign in to continue.');
      }

      try {
        request.identity = await opts.verifier.verifyIdToken(token);
      } catch (error) {
        if (error instanceof TokenVerificationError) {
          // Reason goes to the log for debugging; the client only learns 401
          // and refreshes (§11). "expired" is the one case worth naming to
          // the client so it can distinguish "refresh" from "sign in again".
          request.log.info({ reason: error.reason }, 'ID token rejected');
          throw new AppError(
            'UNAUTHENTICATED',
            error.reason === 'expired' ? 'Your session has expired.' : 'Sign in to continue.',
          );
        }
        throw error;
      }
    });
  },
  { name: 'auth', dependencies: ['error-handler'] },
);
