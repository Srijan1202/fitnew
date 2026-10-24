/**
 * Phase 15 — notification vocabulary and defaults (MASTER-SPEC §21, ADR-021).
 */

export const NOTIFY_KINDS = [
  'workout-reminder',
  'missed-session',
  'protein-gap',
  'streak-at-risk',
  'weigh-in',
  'recovery-checkin',
  'weekly-recap',
  'comeback',
  // Beta 3.5 (owner): a reminder per meal the person usually logs.
  'meal-breakfast',
  'meal-lunch',
  'meal-dinner',
] as const;
export type NotifyKind = (typeof NOTIFY_KINDS)[number];

export const NOTIFY_TONES = ['cheeky', 'gentle'] as const;
export type NotifyTone = (typeof NOTIFY_TONES)[number];

/** Where a tap takes the user. */
export const NOTIFY_SCREENS = ['today', 'plan', 'food-log', 'progress'] as const;
export type NotifyScreen = (typeof NOTIFY_SCREENS)[number];

/** What, done on the phone, makes a scheduled notification pointless (it is cancelled there). */
export const CANCEL_EVENTS = ['workout-started', 'workout-completed', 'food-logged', 'protein-reached', 'weight-logged', 'checkin-logged', 'any-activity', 'app-opened'] as const;
export type CancelEvent = (typeof CANCEL_EVENTS)[number];

/** How a notification ended (the phone reports the first three). */
export const NOTIFY_OUTCOMES = ['delivered', 'opened', 'cancelled'] as const;
export type NotifyOutcome = (typeof NOTIFY_OUTCOMES)[number];

export interface NotifySettings {
  /** All notifications on or off (the rest timer has its own switch in a session). */
  readonly enabled: boolean;
  readonly tone: NotifyTone;
  /** §21: every kind individually toggleable. */
  readonly kinds: Readonly<Record<NotifyKind, boolean>>;
  /** "HH:MM" local; nothing is sent inside [start, end). */
  readonly quietStart: string;
  readonly quietEnd: string;
}

/** §21 defaults; weigh-in off; the Phase 13 check-in reminder off (new, opt-in). */
export const DEFAULT_NOTIFY_SETTINGS: NotifySettings = {
  enabled: true,
  tone: 'cheeky',
  kinds: {
    'workout-reminder': true,
    'missed-session': true,
    'protein-gap': true,
    'streak-at-risk': true,
    'weigh-in': false,
    'recovery-checkin': false,
    'weekly-recap': true,
    comeback: true,
    'meal-breakfast': true,
    'meal-lunch': true,
    'meal-dinner': true,
  },
  quietStart: '22:30',
  quietEnd: '07:30',
};

/**
 * §21 said two a day; beta 3.5 (owner 2026-10-24) raised it to four, to make
 * room for meal reminders. The in-session rest timer is not one.
 */
export const DAILY_CAP = 4;
/** Two notifications on one day are at least this far apart (was 180 with two a day). */
export const MIN_GAP_MINUTES = 120;
/** How far ahead the phone is given a plan; it is rebuilt every time the app syncs. */
export const HORIZON_DAYS = 7;
/** Protein-gap fires only below this share of the target (§21: < 75 %). */
export const PROTEIN_GAP_SHARE = 0.75;
