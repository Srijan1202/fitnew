import type { NextConfig } from 'next';

/**
 * The admin panel reads the same API as the app and never the database:
 * §20 requires every admin action to go through the API so it is
 * authorised and written to audit_logs.
 *
 * Two ways to run it, one origin either way, so the API needs no CORS opening:
 * - Local (ADR-022 D1): `dev` / `build` + `start`. The browser calls `/api/*`
 *   on this server, which forwards to the FITOS API (`FITOS_API_URL`).
 * - Hosted (ADR-022 D1 amendment): `build:static` writes plain files to
 *   `out/`; Caddy on the API server serves them at admin.<domain> and
 *   forwards `/api/*` to the API itself (scripts/aws/admin.ps1).
 */
const API = process.env['FITOS_API_URL'] ?? 'http://localhost:8080';
const STATIC = process.env['npm_lifecycle_event'] === 'build:static';

const nextConfig: NextConfig = STATIC
  ? { reactStrictMode: true, output: 'export', trailingSlash: true }
  : {
      reactStrictMode: true,
      async rewrites() {
        return [{ source: '/api/:path*', destination: `${API}/:path*` }];
      },
    };

export default nextConfig;
