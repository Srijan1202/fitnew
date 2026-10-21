import type { NextConfig } from 'next';

/**
 * The admin panel reads the same API as the app and never the database:
 * §20 requires every admin action to go through the API so it is
 * authorised and written to audit_logs.
 *
 * Phase 16 (ADR-022 D1): the browser calls `/api/*` on this server, which
 * forwards to the FITOS API. One origin, so the API needs no CORS opening.
 */
const API = process.env['FITOS_API_URL'] ?? 'http://localhost:8080';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  async rewrites() {
    return [{ source: '/api/:path*', destination: `${API}/:path*` }];
  },
};

export default nextConfig;
