/**
 * Phase 16 (§20, ADR-022 D2) — make an account an administrator, or stop it
 * being one: sets or removes the Firebase custom claim `role: admin`. Run
 * by the owner, never by the app. The account signs out and in again (or
 * waits up to an hour) for its token to carry the claim.
 *
 *   In the API container (credentials already mounted):
 *     docker exec fitos-api node apps/api/dist/scripts/admin-grant.js you@example.com
 *     docker exec fitos-api node apps/api/dist/scripts/admin-grant.js you@example.com --revoke
 *   On the PC, with apps/api/.env set up:
 *     pnpm --filter @fitos/api admin:grant you@example.com [--revoke]
 */
import { getAuth } from 'firebase-admin/auth';

import { firebaseApp } from '../lib/token-verifier.js';

async function main(): Promise<void> {
  const [email, flag] = process.argv.slice(2);
  if (email === undefined || !email.includes('@')) {
    console.error('usage: admin-grant <email> [--revoke]');
    process.exit(2);
  }
  const projectId = process.env['FIREBASE_PROJECT_ID'];
  if (projectId === undefined || projectId === '') {
    console.error('FIREBASE_PROJECT_ID is not set');
    process.exit(2);
  }
  const credentialsPath = process.env['GOOGLE_APPLICATION_CREDENTIALS'];
  const auth = getAuth(firebaseApp({ projectId, ...(credentialsPath ? { credentialsPath } : {}) }));
  const user = await auth.getUserByEmail(email);
  const claims: Record<string, unknown> = { ...(user.customClaims ?? {}) };
  const revoke = flag === '--revoke';
  if (revoke) delete claims['role'];
  else claims['role'] = 'admin';
  await auth.setCustomUserClaims(user.uid, claims);
  console.log(`${email}: ${revoke ? 'no longer an administrator' : 'now an administrator'}. Sign out and in again for it to take effect.`);
}

main().catch((e: unknown) => {
  console.error((e as { message?: string }).message ?? e);
  process.exit(1);
});
