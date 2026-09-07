import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // The admin panel reads the same API as the app. It never talks to the
  // database directly — §20 requires every admin action to go through the API
  // so it can be authorised and written to audit_logs.
  env: {
    NEXT_PUBLIC_API_BASE_URL: process.env['NEXT_PUBLIC_API_BASE_URL'] ?? 'http://localhost:8080',
  },
};

export default nextConfig;
