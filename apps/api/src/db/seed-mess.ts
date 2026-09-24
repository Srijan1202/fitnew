/**
 * Seeds the mess provider and its six messes from packages/core config
 * (Phase 9) — the only place the MessIT URLs live. Idempotent: upserts by
 * slug / code and never touches mirror status or snapshots. Run by
 * `pnpm db:seed` and by the mess integration tests.
 */
import { sql } from 'drizzle-orm';
import { VIT_DESCRIPTORS, VIT_ENDPOINTS, VIT_VELLORE_PROVIDER_ID, messCode } from '@fitos/core/mess/providers/vit/config';

import type { DatabaseHandle } from './client.js';
import { messProviders, messes } from './schema.js';

export const VIT_PROVIDER_DISPLAY_NAME = 'VIT Vellore';

export async function seedMesses(db: DatabaseHandle['db']): Promise<{ providers: number; messes: number }> {
  return db.transaction(async (tx) => {
    const [provider] = await tx
      .insert(messProviders)
      .values({ slug: VIT_VELLORE_PROVIDER_ID, displayName: VIT_PROVIDER_DISPLAY_NAME })
      .onConflictDoUpdate({ target: messProviders.slug, set: { displayName: sql`excluded.display_name` } })
      .returning({ id: messProviders.id });
    if (provider === undefined) throw new Error('mess provider upsert returned nothing');

    const rows = VIT_DESCRIPTORS.map((d) => {
      const endpoint = VIT_ENDPOINTS.find((e) => e.hostelId === d.hostelId && e.messId === d.messId);
      if (endpoint === undefined) throw new Error(`no endpoint for ${d.hostelId}/${d.messId}`);
      return {
        providerId: provider.id,
        code: messCode(d.hostelId, d.messId),
        hostelId: d.hostelId,
        hostelLabel: d.hostelLabel,
        messId: d.messId,
        messLabel: d.messLabel,
        servesNonVeg: d.servesNonVeg,
        sourceUrl: endpoint.url,
      };
    });
    const upserted = await tx
      .insert(messes)
      .values(rows)
      .onConflictDoUpdate({
        target: messes.code,
        set: {
          hostelLabel: sql`excluded.hostel_label`,
          messLabel: sql`excluded.mess_label`,
          servesNonVeg: sql`excluded.serves_non_veg`,
          sourceUrl: sql`excluded.source_url`,
        },
      })
      .returning({ id: messes.id });
    return { providers: 1, messes: upserted.length };
  });
}
