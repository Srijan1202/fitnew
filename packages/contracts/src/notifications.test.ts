import { describe, expect, it } from 'vitest';

import {
  NOTIFY_KINDS,
  notifyPlanRequestSchema,
  notifyPlanResponseSchema,
  notifySettingsPatchSchema,
  notifySettingsSchema,
  plannedNotificationSchema,
  pushTokenRequestSchema,
} from './notifications.js';

const settings = {
  enabled: true,
  tone: 'cheeky',
  kinds: Object.fromEntries(NOTIFY_KINDS.map((k) => [k, k !== 'weigh-in'])),
  quietStart: '22:30',
  quietEnd: '07:30',
};
const item = {
  id: '6f1c2a10-3b4d-4e5f-8a9b-0c1d2e3f4a5b',
  kind: 'protein-gap',
  localDate: '2026-10-21',
  at: '2026-10-21T13:30:00.000Z',
  title: 'Protein is lagging',
  body: 'Your 120 g target is looking lonely.',
  variant: 'pg-c2',
  tone: 'cheeky',
  screen: 'food-log',
  slot: 'dinner',
  actions: ['snooze'],
  cancelOn: [{ event: 'protein-reached', localDate: '2026-10-21', grams: 90 }],
  why: 'Before dinner, only while protein is under three quarters of your target.',
};

describe('Notification contracts (Phase 15)', () => {
  it('settings: strict, every kind present, clocks as HH:MM', () => {
    expect(notifySettingsSchema.safeParse(settings).success).toBe(true);
    expect(notifySettingsSchema.safeParse({ ...settings, quietStart: '7:30' }).success).toBe(false);
    const missing = Object.fromEntries(Object.entries(settings.kinds).filter(([k]) => k !== 'comeback'));
    expect(notifySettingsSchema.safeParse({ ...settings, kinds: missing }).success).toBe(false);
    expect(notifySettingsSchema.safeParse({ ...settings, kinds: { ...settings.kinds, sms: true } }).success).toBe(false);
  });

  it('patch: any subset, nothing unknown', () => {
    expect(notifySettingsPatchSchema.parse({ kinds: { 'weigh-in': true } })).toEqual({ kinds: { 'weigh-in': true } });
    expect(notifySettingsPatchSchema.safeParse({ tone: 'savage' }).success).toBe(false);
    expect(notifySettingsPatchSchema.safeParse({ maxPerDay: 4 }).success).toBe(false);
  });

  it('a planned item and the plan; events default to none', () => {
    expect(plannedNotificationSchema.safeParse(item).success).toBe(true);
    expect(plannedNotificationSchema.safeParse({ ...item, screen: 'settings' }).success).toBe(false);
    expect(notifyPlanResponseSchema.safeParse({ generatedAt: item.at, timeZone: 'Asia/Kolkata', settings, items: [item] }).success).toBe(true);
    expect(notifyPlanRequestSchema.parse({})).toEqual({ events: [] });
    expect(notifyPlanRequestSchema.safeParse({ events: [{ id: item.id, event: 'snoozed', at: item.at }] }).success).toBe(false);
  });

  it('push token: android only', () => {
    expect(pushTokenRequestSchema.safeParse({ token: 'x'.repeat(40), platform: 'android' }).success).toBe(true);
    expect(pushTokenRequestSchema.safeParse({ token: 'x'.repeat(40), platform: 'ios' }).success).toBe(false);
  });
});
