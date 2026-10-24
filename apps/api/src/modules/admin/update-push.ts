/**
 * Beta 3.5 (ADR-026 amendment): "FITOS beta N is out" as a push to every
 * phone with notifications on, sent by an admin after a release. The version
 * is the website's own (its /version.json), never typed. Once per build:
 * a second send for the same build is refused. Tokens FCM no longer knows
 * are removed. Audited.
 */
import type { FastifyInstance } from 'fastify';
import type { ZodTypeProvider } from 'fastify-type-provider-zod';
import { and, count, desc, eq, inArray } from 'drizzle-orm';
import { adminUpdatePushResultSchema, adminUpdatePushStatusSchema, errorEnvelopeSchema, type AdminUpdatePushResult, type AdminUpdatePushStatus } from '@fitos/contracts';

import type { DatabaseHandle } from '../../db/client.js';
import { auditLogs, pushTokens } from '../../db/schema.js';
import { AppError } from '../../lib/errors.js';
import { releaseLabel, type PushSender, type ReleaseFeed } from '../../lib/push.js';
import { requireAdmin } from '../../plugins/auth.js';

type Db = DatabaseHandle['db'];

const ACTION = 'push.update';
const DOWNLOAD = 'https://tryfitos.me/download/';

export class UpdatePushService {
  constructor(
    private readonly db: Db,
    private readonly push: PushSender,
    private readonly feed: ReleaseFeed,
  ) {}

  private async sentAt(build: number): Promise<Date | null> {
    const [row] = await this.db
      .select({ at: auditLogs.occurredAt })
      .from(auditLogs)
      .where(and(eq(auditLogs.action, ACTION), eq(auditLogs.entityId, String(build))))
      .orderBy(desc(auditLogs.occurredAt))
      .limit(1);
    return row?.at ?? null;
  }

  async status(): Promise<AdminUpdatePushStatus> {
    const [latest, [devices]] = await Promise.all([this.feed.latest(), this.db.select({ n: count() }).from(pushTokens)]);
    const sent = latest === null ? null : await this.sentAt(latest.build);
    return {
      latest: latest === null ? null : { version: latest.version, build: latest.build, label: releaseLabel(latest.version) },
      devices: Number(devices?.n ?? 0),
      sentAt: sent?.toISOString() ?? null,
    };
  }

  async send(actor: string | null): Promise<AdminUpdatePushResult> {
    const latest = await this.feed.latest();
    if (latest === null) throw new AppError('NOT_FOUND', 'Could not read the website\'s latest version.', [{ path: 'release', issue: 'unknown' }]);
    if ((await this.sentAt(latest.build)) !== null) {
      throw new AppError('CONFLICT', `Everyone was already told about build ${latest.build}.`, [{ path: 'release', issue: 'already-sent' }]);
    }
    const label = releaseLabel(latest.version);
    const tokens = (await this.db.select({ token: pushTokens.token }).from(pushTokens)).map((r) => r.token);
    const result =
      tokens.length === 0
        ? { sent: 0, invalid: [] as string[] }
        : await this.push.send(tokens, {
            title: `FITOS ${label} is out`,
            body: 'Tap to update. It installs over your version and keeps your data.',
            data: { type: 'update', build: String(latest.build), url: DOWNLOAD },
          });
    if (result.invalid.length > 0) await this.db.delete(pushTokens).where(inArray(pushTokens.token, [...result.invalid]));
    await this.db.insert(auditLogs).values({
      actorUserId: actor,
      action: ACTION,
      entity: 'release',
      entityId: String(latest.build),
      metadata: { version: latest.version, devices: tokens.length, sent: result.sent, removed: result.invalid.length },
    });
    return { build: latest.build, label, devices: tokens.length, sent: result.sent, removed: result.invalid.length };
  }
}

export async function updatePushRoutes(app: FastifyInstance): Promise<void> {
  const service = new UpdatePushService(app.database.db, app.push, app.releaseFeed);
  const typed = app.withTypeProvider<ZodTypeProvider>();
  const security = [{ bearerAuth: [] }];
  const errors = { 401: errorEnvelopeSchema, 403: errorEnvelopeSchema, 404: errorEnvelopeSchema, 409: errorEnvelopeSchema };
  const admin = { preValidation: requireAdmin };

  typed.get('/admin/push/update', {
    ...admin,
    schema: {
      summary: "The website's latest beta, how many phones can be told, and whether they were",
      tags: ['admin'],
      security,
      response: { 200: adminUpdatePushStatusSchema, ...errors },
    },
  }, async () => service.status());

  typed.post('/admin/push/update', {
    ...admin,
    schema: {
      summary: 'Tell every phone with notifications on that the latest beta is out (once per build; audited)',
      tags: ['admin'],
      security,
      response: { 200: adminUpdatePushResultSchema, ...errors },
    },
  }, async (request) => service.send(request.userId));
}
