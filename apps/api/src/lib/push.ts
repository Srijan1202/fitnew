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
    // FCM takes at most 500 tokens per call.
    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      const r = await messaging.sendEachForMulticast({
        tokens: [...batch],
        notification: { title: message.title, body: message.body },
        data: { ...message.data },
        android: { priority: 'high' },
      });
      sent += r.successCount;
      r.responses.forEach((res, k) => {
        if (!res.success && res.error !== undefined && GONE.has(res.error.code)) invalid.push(batch[k]!);
      });
    }
    return { sent, invalid };
  }
}

/** Test apps: records every send; tokens in [gone] answer as uninstalled. */
export class RecordingPushSender implements PushSender {
  readonly sends: { tokens: readonly string[]; message: PushMessage }[] = [];
  readonly gone = new Set<string>();

  async send(tokens: readonly string[], message: PushMessage): Promise<PushResult> {
    this.sends.push({ tokens: [...tokens], message });
    const invalid = tokens.filter((t) => this.gone.has(t));
    return { sent: tokens.length - invalid.length, invalid };
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
