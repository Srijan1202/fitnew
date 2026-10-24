/**
 * Beta 3.5: push notifications from the server (backlog F9, first use: "a
 * new version is out"). The phones have registered their FCM tokens since
 * Phase 15 (`push_tokens`); this is the sender. A seam, like the token
 * verifier: production sends through Firebase Cloud Messaging, test apps
 * record. Also the latest beta as the website publishes it, read here so the
 * admin panel never has to cross origins.
 */
import { getMessaging } from 'firebase-admin/messaging';

import { firebaseApp, type FirebaseVerifierOptions } from './token-verifier.js';

declare module 'fastify' {
  interface FastifyInstance {
    push: PushSender;
    releaseFeed: ReleaseFeed;
  }
}

export interface PushMessage {
  readonly title: string;
  readonly body: string;
  /** Delivered to the app with the notification. */
  readonly data: Readonly<Record<string, string>>;
}

export interface PushResult {
  readonly sent: number;
  /** Tokens FCM no longer knows (uninstalled, signed out): to be removed. */
  readonly invalid: readonly string[];
  /** Every failed send by FCM's error code, so a refusal is never silent. */
  readonly errors: Readonly<Record<string, number>>;
  /** The first failure's own words (FCM's message), for the admin and the log. */
  readonly detail: string | null;
}

export interface PushSender {
  send(tokens: readonly string[], message: PushMessage): Promise<PushResult>;
}

const GONE = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token', 'messaging/invalid-argument']);

export class FirebasePushSender implements PushSender {
  constructor(private readonly options: FirebaseVerifierOptions) {}

  async send(tokens: readonly string[], message: PushMessage): Promise<PushResult> {
    const messaging = getMessaging(firebaseApp(this.options));
    let sent = 0;
    const invalid: string[] = [];
    const errors: Record<string, number> = {};
    let detail: string | null = null;
    const failed = (code: string, message: string | undefined, n = 1) => {
      errors[code] = (errors[code] ?? 0) + n;
      if (detail === null && !GONE.has(code)) detail = (message ?? code).slice(0, 300);
    };
    // FCM takes at most 500 tokens per call.
    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      let r;
      try {
        r = await messaging.sendEachForMulticast({
          tokens: [...batch],
          notification: { title: message.title, body: message.body },
          data: { ...message.data },
          android: { priority: 'high' },
        });
      } catch (e) {
        // Credentials or permission: the whole batch is refused.
        const err = e as { code?: string; message?: string };
        failed(err.code ?? 'send-failed', err.message, batch.length);
        continue;
      }
      sent += r.successCount;
      r.responses.forEach((res, k) => {
        if (res.success) return;
        const code = res.error?.code ?? 'unknown';
        failed(code, res.error?.message);
        if (GONE.has(code)) invalid.push(batch[k]!);
      });
    }
    return { sent, invalid, errors, detail };
  }
}

/**
 * Test apps: records every send; tokens in [gone] answer as uninstalled;
 * [refusal] (an FCM code) refuses every token, as missing permission does.
 */
export class RecordingPushSender implements PushSender {
  readonly sends: { tokens: readonly string[]; message: PushMessage }[] = [];
  readonly gone = new Set<string>();
  refusal: string | null = null;

  async send(tokens: readonly string[], message: PushMessage): Promise<PushResult> {
    this.sends.push({ tokens: [...tokens], message });
    if (this.refusal !== null) return { sent: 0, invalid: [], errors: { [this.refusal]: tokens.length }, detail: `refused: ${this.refusal}` };
    const invalid = tokens.filter((t) => this.gone.has(t));
    const errors = invalid.length > 0 ? { 'messaging/registration-token-not-registered': invalid.length } : {};
    return { sent: tokens.length - invalid.length, invalid, errors, detail: null };
  }
}

/** The latest beta the website offers (its /version.json). */
export interface LatestBeta {
  readonly version: string;
  readonly build: number;
}

export interface ReleaseFeed {
  latest(): Promise<LatestBeta | null>;
}

export class WebsiteReleaseFeed implements ReleaseFeed {
  constructor(private readonly url = 'https://tryfitos.me/version.json') {}

  async latest(): Promise<LatestBeta | null> {
    try {
      const r = await fetch(this.url, { signal: AbortSignal.timeout(5000) });
      if (!r.ok) return null;
      const j = (await r.json()) as { version?: unknown; build?: unknown };
      return typeof j.version === 'string' && typeof j.build === 'number' && Number.isInteger(j.build) ? { version: j.version, build: j.build } : null;
    } catch {
      return null;
    }
  }
}

/** Test apps: whatever the test says. */
export class ScriptedReleaseFeed implements ReleaseFeed {
  release: LatestBeta | null = null;

  async latest(): Promise<LatestBeta | null> {
    return this.release;
  }
}

/** "1.0.0-beta.3.5" → "beta 3.5", as the app says it. */
export function releaseLabel(version: string): string {
  const m = /beta\.([0-9.]+)$/.exec(version);
  return m === null ? version : `beta ${m[1]}`;
}
