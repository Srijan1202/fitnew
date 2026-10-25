/**
 * Beta 3.7 (owner: "automatic announcement when we publish"): "FITOS beta N
 * is out" to every phone with notifications on, the same send as Admin →
 * Announce update (once per build, audited, dead tokens removed). The
 * website's deploy runs it after the new APK is served:
 *
 *   docker exec fitos-api-<sha7> node apps/api/dist/scripts/announce-update.js
 *   pnpm --filter @fitos/api announce:update            (on the PC)
 *
 * Exit 0 when sent or when this build was already announced; 1 when the
 * website's version cannot be read or no phone was reached (the panel's
 * button can then try again).
 */
import { createDatabase } from '../db/client.js';
import { AppError } from '../lib/errors.js';
import { FirebasePushSender, WebsiteReleaseFeed } from '../lib/push.js';
import { UpdatePushService } from '../modules/admin/update-push.js';

async function main(): Promise<number> {
  const url = process.env['DATABASE_URL'];
  const projectId = process.env['FIREBASE_PROJECT_ID'];
  if (url === undefined || projectId === undefined || projectId === '') {
    console.error('DATABASE_URL and FIREBASE_PROJECT_ID are required');
    return 2;
  }
  const credentialsPath = process.env['GOOGLE_APPLICATION_CREDENTIALS'];
  const handle = createDatabase(url);
  try {
    const service = new UpdatePushService(handle.db, new FirebasePushSender({ projectId, ...(credentialsPath ? { credentialsPath } : {}) }), new WebsiteReleaseFeed());
    const r = await service.send(null, 'website-deploy');
    const errors = Object.entries(r.errors).map(([code, n]) => `${code} ${n}`).join(', ');
    console.log(`announced ${r.label} (build ${r.build}): ${r.sent} of ${r.devices} phones reached, ${r.removed} old tokens removed${r.failed > 0 ? `, ${r.failed} failed (${errors})` : ''}`);
    return r.devices > 0 && r.sent === 0 ? 1 : 0;
  } catch (e: unknown) {
    if (e instanceof AppError && e.code === 'CONFLICT') {
      console.log(e.message);
      return 0;
    }
    console.error((e as { message?: string }).message ?? e);
    return 1;
  } finally {
    await handle.client.end({ timeout: 5 });
  }
}

main().then((code) => process.exit(code));
