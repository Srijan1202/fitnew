/**
 * Community (beta 5.8, ADR-057; owner 2026-11-08: "Friends / VIT leaderboard
 * ... dont just focus on VIT we have to make world level"). Opt-in: nobody
 * is seen or found until they join with a handle, and joining is its own
 * consent (`community`, kept in consent_records with the policy version).
 * Boards show counts only: gym sessions and run distance this week, and the
 * streak. Never weights, food, body, readiness, sleep, heart rate or routes.
 * Beta 6.3 (Community that talks): an opt-in feed for friends, kudos, nudges,
 * month and all-time boards, and suggestions.
 */
import { z } from 'zod';

import { avatarIdSchema } from './premium.js';

const iso = z.string().datetime({ offset: true });

/* ------------------------------------------------------------ handles -- */

/** A handle: 3–20 of a–z, 0–9 and _, stored lower-case; shown as @handle. */
export const HANDLE_PATTERN = /^[a-z0-9_]{3,20}$/;

/** Handles nobody may take: they could pass for FITOS itself. */
export const RESERVED_HANDLES: readonly string[] = [
  'fitos', 'fitosapp', 'fitos_ai', 'admin', 'administrator', 'support', 'help', 'official', 'moderator', 'mod', 'staff',
  'team', 'root', 'system', 'null', 'undefined', 'anonymous', 'everyone', 'owner', 'security', 'privacy',
];

/**
 * Words no handle or club name may contain, checked after undoing common
 * letter swaps (0→o, 1→i, 3→e, 4→a, 5→s, 7→t, @→a, $→s). STRONG ones count
 * anywhere; the others only at the start of a word, so "grapes" and
 * "peacock" pass. Short on purpose: reports and the admin panel deal with
 * the rest.
 */
export const BLOCKED_STRONG: readonly string[] = [
  'fuck', 'nigger', 'nigga', 'faggot', 'cunt', 'chutiya', 'chutia', 'madarchod', 'bhenchod', 'behenchod', 'bhosdi',
];
export const BLOCKED_WORDS: readonly string[] = [
  'shit', 'bitch', 'dick', 'cock', 'pussy', 'whore', 'slut', 'bastard', 'asshole', 'retard', 'rape', 'porn', 'nazi',
  'hitler', 'gandu', 'randi', 'lund', 'lauda', 'loda', 'harami', 'kamina',
];

const unleet = (s: string): string =>
  s
    .toLowerCase()
    .replace(/0/g, 'o')
    .replace(/1/g, 'i')
    .replace(/3/g, 'e')
    .replace(/4/g, 'a')
    .replace(/5/g, 's')
    .replace(/7/g, 't')
    .replace(/@/g, 'a')
    .replace(/\$/g, 's');

/** True when the text holds a blocked word (letter swaps undone). */
export function hasBlockedWord(text: string): boolean {
  const plain = unleet(text);
  const letters = plain.replace(/[^a-z]/g, '');
  if (BLOCKED_STRONG.some((w) => letters.includes(w))) return true;
  const words = plain.split(/[^a-z]+/).filter((w) => w.length > 0);
  return words.some((word) => BLOCKED_WORDS.some((w) => word.startsWith(w)));
}

/** Why a handle is refused, or null when it may be used. */
export function handleProblem(handle: string): 'format' | 'reserved' | 'word' | null {
  if (!HANDLE_PATTERN.test(handle)) return 'format';
  if (RESERVED_HANDLES.includes(handle) || handle.startsWith('fitos')) return 'reserved';
  if (hasBlockedWord(handle)) return 'word';
  return null;
}

export const handleSchema = z
  .string()
  .trim()
  .transform((s) => s.replace(/^@/, '').toLowerCase())
  .pipe(z.string().regex(HANDLE_PATTERN, 'Use 3–20 letters, numbers or _.'));

/* ---------------------------------------------------------- countries -- */

/** ISO 3166-1 alpha-2 codes with English names: the world board's countries. */
export const COUNTRIES = {
  AD: "Andorra",
  AE: "United Arab Emirates",
  AF: "Afghanistan",
  AG: "Antigua & Barbuda",
  AI: "Anguilla",
  AL: "Albania",
  AM: "Armenia",
  AO: "Angola",
  AQ: "Antarctica",
  AR: "Argentina",
  AS: "American Samoa",
  AT: "Austria",
  AU: "Australia",
  AW: "Aruba",
  AX: "Åland Islands",
  AZ: "Azerbaijan",
  BA: "Bosnia & Herzegovina",
  BB: "Barbados",
  BD: "Bangladesh",
  BE: "Belgium",
  BF: "Burkina Faso",
  BG: "Bulgaria",
  BH: "Bahrain",
  BI: "Burundi",
  BJ: "Benin",
  BL: "St. Barthélemy",
  BM: "Bermuda",
  BN: "Brunei",
  BO: "Bolivia",
  BQ: "Caribbean Netherlands",
  BR: "Brazil",
  BS: "Bahamas",
  BT: "Bhutan",
  BV: "Bouvet Island",
  BW: "Botswana",
  BY: "Belarus",
  BZ: "Belize",
  CA: "Canada",
  CC: "Cocos (Keeling) Islands",
  CD: "Congo - Kinshasa",
  CF: "Central African Republic",
  CG: "Congo - Brazzaville",
  CH: "Switzerland",
  CI: "Côte d’Ivoire",
  CK: "Cook Islands",
  CL: "Chile",
  CM: "Cameroon",
  CN: "China",
  CO: "Colombia",
  CR: "Costa Rica",
  CU: "Cuba",
  CV: "Cape Verde",
  CW: "Curaçao",
  CX: "Christmas Island",
  CY: "Cyprus",
  CZ: "Czechia",
  DE: "Germany",
  DJ: "Djibouti",
  DK: "Denmark",
  DM: "Dominica",
  DO: "Dominican Republic",
  DY: "Benin",
  DZ: "Algeria",
  EC: "Ecuador",
  EE: "Estonia",
  EG: "Egypt",
  EH: "Western Sahara",
  ER: "Eritrea",
  ES: "Spain",
  ET: "Ethiopia",
  FI: "Finland",
  FJ: "Fiji",
  FK: "Falkland Islands",
  FM: "Micronesia",
  FO: "Faroe Islands",
  FR: "France",
  GA: "Gabon",
  GB: "United Kingdom",
  GD: "Grenada",
  GE: "Georgia",
  GF: "French Guiana",
  GG: "Guernsey",
  GH: "Ghana",
  GI: "Gibraltar",
  GL: "Greenland",
  GM: "Gambia",
  GN: "Guinea",
  GP: "Guadeloupe",
  GQ: "Equatorial Guinea",
  GR: "Greece",
  GS: "South Georgia & South Sandwich Islands",
  GT: "Guatemala",
  GU: "Guam",
  GW: "Guinea-Bissau",
  GY: "Guyana",
  HK: "Hong Kong SAR China",
  HM: "Heard & McDonald Islands",
  HN: "Honduras",
  HR: "Croatia",
  HT: "Haiti",
  HU: "Hungary",
  HV: "Burkina Faso",
  ID: "Indonesia",
  IE: "Ireland",
  IL: "Israel",
  IM: "Isle of Man",
  IN: "India",
  IO: "British Indian Ocean Territory",
  IQ: "Iraq",
  IR: "Iran",
  IS: "Iceland",
  IT: "Italy",
  JE: "Jersey",
  JM: "Jamaica",
  JO: "Jordan",
  JP: "Japan",
  KE: "Kenya",
  KG: "Kyrgyzstan",
  KH: "Cambodia",
  KI: "Kiribati",
  KM: "Comoros",
  KN: "St. Kitts & Nevis",
  KP: "North Korea",
  KR: "South Korea",
  KW: "Kuwait",
  KY: "Cayman Islands",
  KZ: "Kazakhstan",
  LA: "Laos",
  LB: "Lebanon",
  LC: "St. Lucia",
  LI: "Liechtenstein",
  LK: "Sri Lanka",
  LR: "Liberia",
  LS: "Lesotho",
  LT: "Lithuania",
  LU: "Luxembourg",
  LV: "Latvia",
  LY: "Libya",
  MA: "Morocco",
  MC: "Monaco",
  MD: "Moldova",
  ME: "Montenegro",
  MF: "St. Martin",
  MG: "Madagascar",
  MH: "Marshall Islands",
  MK: "North Macedonia",
  ML: "Mali",
  MM: "Myanmar (Burma)",
  MN: "Mongolia",
  MO: "Macao SAR China",
  MP: "Northern Mariana Islands",
  MQ: "Martinique",
  MR: "Mauritania",
  MS: "Montserrat",
  MT: "Malta",
  MU: "Mauritius",
  MV: "Maldives",
  MW: "Malawi",
  MX: "Mexico",
  MY: "Malaysia",
  MZ: "Mozambique",
  NA: "Namibia",
  NC: "New Caledonia",
  NE: "Niger",
  NF: "Norfolk Island",
  NG: "Nigeria",
  NH: "Vanuatu",
  NI: "Nicaragua",
  NL: "Netherlands",
  NO: "Norway",
  NP: "Nepal",
  NR: "Nauru",
  NU: "Niue",
  NZ: "New Zealand",
  OM: "Oman",
  PA: "Panama",
  PE: "Peru",
  PF: "French Polynesia",
  PG: "Papua New Guinea",
  PH: "Philippines",
  PK: "Pakistan",
  PL: "Poland",
  PM: "St. Pierre & Miquelon",
  PN: "Pitcairn Islands",
  PR: "Puerto Rico",
  PS: "Palestinian Territories",
  PT: "Portugal",
  PW: "Palau",
  PY: "Paraguay",
  QA: "Qatar",
  RE: "Réunion",
  RH: "Zimbabwe",
  RO: "Romania",
  RS: "Serbia",
  RU: "Russia",
  RW: "Rwanda",
  SA: "Saudi Arabia",
  SB: "Solomon Islands",
  SC: "Seychelles",
  SD: "Sudan",
  SE: "Sweden",
  SG: "Singapore",
  SH: "St. Helena",
  SI: "Slovenia",
  SJ: "Svalbard & Jan Mayen",
  SK: "Slovakia",
  SL: "Sierra Leone",
  SM: "San Marino",
  SN: "Senegal",
  SO: "Somalia",
  SR: "Suriname",
  SS: "South Sudan",
  ST: "São Tomé & Príncipe",
  SV: "El Salvador",
  SX: "Sint Maarten",
  SY: "Syria",
  SZ: "Eswatini",
  TC: "Turks & Caicos Islands",
  TD: "Chad",
  TF: "French Southern Territories",
  TG: "Togo",
  TH: "Thailand",
  TJ: "Tajikistan",
  TK: "Tokelau",
  TL: "Timor-Leste",
  TM: "Turkmenistan",
  TN: "Tunisia",
  TO: "Tonga",
  TR: "Türkiye",
  TT: "Trinidad & Tobago",
  TV: "Tuvalu",
  TW: "Taiwan",
  TZ: "Tanzania",
  UA: "Ukraine",
  UG: "Uganda",
  UK: "United Kingdom",
  UM: "U.S. Outlying Islands",
  US: "United States",
  UY: "Uruguay",
  UZ: "Uzbekistan",
  VA: "Vatican City",
  VC: "St. Vincent & Grenadines",
  VD: "Vietnam",
  VE: "Venezuela",
  VG: "British Virgin Islands",
  VI: "U.S. Virgin Islands",
  VN: "Vietnam",
  VU: "Vanuatu",
  WF: "Wallis & Futuna",
  WS: "Samoa",
  XK: "Kosovo",
  YE: "Yemen",
  YT: "Mayotte",
  ZA: "South Africa",
  ZM: "Zambia",
  ZW: "Zimbabwe",
} as const;
export type CountryCode = keyof typeof COUNTRIES;
export const COUNTRY_CODES = Object.keys(COUNTRIES) as CountryCode[];
export const countrySchema = z.string().refine((c): c is CountryCode => Object.hasOwn(COUNTRIES, c), 'Not a country code.');

/* ------------------------------------------------------------ profile -- */

/**
 * Beta 6.3 (C1, owner Q1): what a member shares with friends in the feed,
 * each kind switched on separately; nothing until chosen.
 */
export const FEED_KINDS = ['session', 'run', 'record', 'streak'] as const;
export const feedKindSchema = z.enum(FEED_KINDS);
export type FeedKind = z.infer<typeof feedKindSchema>;

export const communityProfileSchema = z
  .object({
    handle: z.string(),
    avatarId: avatarIdSchema.nullable(),
    country: z.string().nullable(),
    /** On the world board (a separate choice, off by default). */
    onWorld: z.boolean(),
    joinedAt: iso,
    /** Beta 6.3 (C1): the kinds shared with friends in the feed (none at first). */
    feed: z.array(feedKindSchema),
    /** Beta 6.3 (C16, owner Q3): suggested to friends of friends and club-mates (on at first). */
    suggest: z.boolean(),
    /** Beta 6.3 (C2, C3): the evening kudos summary and nudges as notifications (on at first). */
    notify: z.boolean(),
  })
  .strict();
export type CommunityProfile = z.infer<typeof communityProfileSchema>;

export const communityMeSchema = z
  .object({
    /** Null until the person joins. */
    profile: communityProfileSchema.nullable(),
    /** Friend requests waiting for this person's answer. */
    incoming: z.number().int().nonnegative(),
  })
  .strict();
export type CommunityMe = z.infer<typeof communityMeSchema>;

export const joinCommunitySchema = z
  .object({
    handle: handleSchema,
    country: countrySchema.nullable(),
    onWorld: z.boolean(),
    /** The policy version the person accepted (the `community` consent). */
    policyVersion: z.string().min(1),
  })
  .strict();
export type JoinCommunityRequest = z.infer<typeof joinCommunitySchema>;

export const updateCommunitySchema = z
  .object({
    handle: handleSchema.optional(),
    country: countrySchema.nullable().optional(),
    onWorld: z.boolean().optional(),
    feed: z
      .array(feedKindSchema)
      .max(FEED_KINDS.length)
      .refine((k) => new Set(k).size === k.length, 'Each kind once.')
      .optional(),
    suggest: z.boolean().optional(),
    notify: z.boolean().optional(),
  })
  .strict()
  .refine((b) => Object.keys(b).length > 0, 'Nothing to change.');
export type UpdateCommunityRequest = z.infer<typeof updateCommunitySchema>;

/* ------------------------------------------------------------- people -- */

/** Another member as anyone may see them: never more than this. */
export const communityPersonSchema = z
  .object({
    userId: z.string().uuid(),
    handle: z.string(),
    avatarId: avatarIdSchema.nullable(),
    country: z.string().nullable(),
  })
  .strict();
export type CommunityPerson = z.infer<typeof communityPersonSchema>;

export const searchQuerySchema = z.object({ q: z.string().trim().min(2).max(21) }).strict();
export const personListSchema = z.object({ items: z.array(communityPersonSchema) }).strict();

export const friendRequestSchema = z.object({ handle: handleSchema }).strict();

export const friendsResponseSchema = z
  .object({
    friends: z.array(communityPersonSchema),
    /** Asked you; waiting for your answer. */
    incoming: z.array(communityPersonSchema),
    /** You asked; waiting for theirs. */
    outgoing: z.array(communityPersonSchema),
  })
  .strict();
export type FriendsResponse = z.infer<typeof friendsResponseSchema>;

/**
 * Beta 6.2 (C4): a friend or club-mate's profile, board data only (owner
 * 2026-11-11): the counts this week, the last 4 weeks, the clubs you share.
 */
export const COMMUNITY_HISTORY_WEEKS = 4;
export const weekCountsSchema = z
  .object({
    /** Monday of that week. */
    weekFrom: z.string(),
    sessions: z.number().int().nonnegative(),
    runM: z.number().int().nonnegative(),
    activeDays: z.number().int().min(0).max(7),
    /** Sessions done of those planned, in per cent; null without a plan that week. */
    keptPct: z.number().int().min(0).max(100).nullable(),
  })
  .strict();
export type WeekCounts = z.infer<typeof weekCountsSchema>;

export const personProfileSchema = z
  .object({
    person: communityPersonSchema,
    relation: z.enum(['friend', 'club-mate']),
    friendsSince: iso.nullable(),
    streak: z.number().int().nonnegative(),
    thisWeek: weekCountsSchema,
    /** The weeks before this one, oldest first, a zero week when nothing counted. */
    weeks: z.array(weekCountsSchema),
    clubsInCommon: z.array(z.object({ id: z.string().uuid(), name: z.string() }).strict()),
    /**
     * Beta 6.3 (C3): a friend can be nudged (`can`), counted something in the
     * last 3 days (`active`), or was nudged by you this week (`sent`); null
     * for a club-mate who is not a friend.
     */
    nudge: z.enum(['can', 'active', 'sent']).nullable(),
  })
  .strict();
export type PersonProfile = z.infer<typeof personProfileSchema>;

/* ------------------------------------------------- beta 6.3: the feed -- */

/**
 * A post's kind: a counted session ("finished Push"), a counted run ("ran
 * 5.2 km"), a lift's record, a run distance's record, a streak milestone.
 */
export const POST_KINDS = ['session', 'run', 'lift-record', 'run-record', 'streak'] as const;
export const postKindSchema = z.enum(POST_KINDS);
export type PostKind = z.infer<typeof postKindSchema>;

export const feedPostSchema = z
  .object({
    id: z.string().uuid(),
    person: communityPersonSchema,
    kind: postKindSchema,
    /**
     * session: the day's name ("Push"); lift-record: the lift; run-record: the
     * distance (a running EFFORT_KEYS value); run and streak: null.
     */
    title: z.string().nullable(),
    /** run: metres; streak: days; lift-record: other lifts with a record in that session; else null. */
    value: z.number().int().nonnegative().nullable(),
    at: iso,
    kudos: z.number().int().nonnegative(),
    /** The viewer cheered it. */
    cheered: z.boolean(),
    mine: z.boolean(),
    /** On your own posts: who cheered, newest first (at most 10); empty on others'. */
    cheeredBy: z.array(communityPersonSchema),
  })
  .strict();
export type FeedPost = z.infer<typeof feedPostSchema>;

/** Beta 6.3 (C3): a nudge you received in the last 3 days. */
export const nudgeSchema = z.object({ person: communityPersonSchema, at: iso }).strict();

export const feedQuerySchema = z.object({ before: iso.optional() }).strict();
export const feedSchema = z
  .object({
    items: z.array(feedPostSchema),
    /** Pass as `before` for older posts; null at the end (the feed covers 14 days). */
    next: iso.nullable(),
    /** Nudges received in the last 3 days, newest first (on the first page only). */
    nudges: z.array(nudgeSchema),
  })
  .strict();
export type Feed = z.infer<typeof feedSchema>;

export const FEED_PAGE = 20;

export const kudosResultSchema = z.object({ kudos: z.number().int().nonnegative(), cheered: z.boolean() }).strict();

/* ------------------------------------------- beta 6.3: suggestions -- */

export const suggestionSchema = z
  .object({
    person: communityPersonSchema,
    /** Friends you both have: a count, never who (owner Q3). */
    mutualFriends: z.number().int().nonnegative(),
    /** A club you are both in, by name; null when none. */
    club: z.string().nullable(),
  })
  .strict();
export type Suggestion = z.infer<typeof suggestionSchema>;
export const suggestionListSchema = z.object({ items: z.array(suggestionSchema) }).strict();
export const SUGGESTIONS_SHOWN = 20;

/** Beta 6.2 (S7): after a decline, the same person cannot ask again for this long. */
export const FRIEND_DECLINE_COOLDOWN_DAYS = 7;

/** What a friend request did: sent, or accepted because they had asked you. */
export const friendRequestResultSchema = z.object({ status: z.enum(['requested', 'friends']) }).strict();

export const blockRequestSchema = z.object({ userId: z.string().uuid() }).strict();

/* -------------------------------------------------------------- clubs -- */

/** A club's name: 3–40 characters, no blocked word. */
export const clubNameSchema = z
  .string()
  .trim()
  .min(3)
  .max(40)
  .regex(/^[\p{L}\p{N} .,'&()-]+$/u, 'Letters, numbers, spaces and . , \' & ( ) - only.')
  .refine((n) => !hasBlockedWord(n), 'Choose another name.');

/** A join code: 8 of A–Z and 2–9 (no 0/O/1/I), shown in two fours. */
export const CLUB_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
export const clubCodeSchema = z
  .string()
  .trim()
  .transform((s) => s.replace(/[\s-]/g, '').toUpperCase())
  .pipe(z.string().regex(/^[A-HJ-NP-Z2-9]{8}$/, 'A club code is 8 letters and numbers.'));

export const clubSchema = z
  .object({
    id: z.string().uuid(),
    name: z.string(),
    code: z.string(),
    members: z.number().int().nonnegative(),
    /** You made it: you can remove members' access by deleting it. */
    mine: z.boolean(),
    createdAt: iso,
  })
  .strict();
export type Club = z.infer<typeof clubSchema>;
export const clubListSchema = z.object({ items: z.array(clubSchema) }).strict();
export const createClubSchema = z.object({ name: clubNameSchema }).strict();
export const joinClubSchema = z.object({ code: clubCodeSchema }).strict();

/** Beta 6.2 (C5): the owner's changes. */
export const renameClubSchema = z.object({ name: clubNameSchema }).strict();
export const passClubSchema = z.object({ userId: z.string().uuid() }).strict();

/** Beta 6.2 (C8, Q1): the links that open FITOS (Android App Links). */
export const clubInviteUrl = (code: string): string => `https://tryfitos.me/c/${code}`;
export const friendInviteUrl = (handle: string): string => `https://tryfitos.me/u/${handle}`;

/** Clubs one person may make, and join. */
export const MAX_CLUBS_OWNED = 5;
export const MAX_CLUBS_JOINED = 20;
export const MAX_CLUB_MEMBERS = 500;
export const MAX_FRIENDS = 300;

/* ------------------------------------------------------------- boards -- */

/**
 * What a board ranks by: gym sessions (the default) or run distance; beta 6.2
 * (C11): the streak, active days (a counted session or run) and the plan kept
 * (sessions done of those planned up to today).
 */
export const BOARD_METRICS = ['sessions', 'distance', 'streak', 'active-days', 'plan'] as const;
export const boardMetricSchema = z.enum(BOARD_METRICS);
export type BoardMetric = z.infer<typeof boardMetricSchema>;

/** Beta 6.3 (C13, owner Q4): this week, this month, or since joining Community. */
export const BOARD_PERIODS = ['week', 'month', 'all'] as const;
export const boardPeriodSchema = z.enum(BOARD_PERIODS);
export type BoardPeriod = z.infer<typeof boardPeriodSchema>;

export const boardQuerySchema = z
  .object({ metric: boardMetricSchema.default('sessions'), period: boardPeriodSchema.default('week'), country: countrySchema.optional() })
  .strict();

export const boardRowSchema = z
  .object({
    rank: z.number().int().positive(),
    userId: z.string().uuid(),
    handle: z.string(),
    avatarId: avatarIdSchema.nullable(),
    country: z.string().nullable(),
    /** Gym sessions that count this week (at most one a day). */
    sessions: z.number().int().nonnegative(),
    /** Run distance that counts this week, in metres. */
    runM: z.number().int().nonnegative(),
    /** The current streak, in days. */
    streak: z.number().int().nonnegative(),
    /** Beta 6.2: days this week with a counted session or run (beta 6.3: in the board's period). */
    activeDays: z.number().int().nonnegative(),
    /** Beta 6.2: sessions done of those planned up to today, in per cent; null without a plan. */
    keptPct: z.number().int().min(0).max(100).nullable(),
    me: z.boolean(),
  })
  .strict();
export type BoardRow = z.infer<typeof boardRowSchema>;

/** Beta 6.2 (C12): last week on this board. */
export const lastWeekSchema = z
  .object({
    weekFrom: z.string(),
    /** The top three last week (ties share a place). */
    podium: z.array(boardRowSchema),
    /** The viewer's place last week; null when they were not on it. */
    myRank: z.number().int().positive().nullable(),
    /** Places gained since the week before (negative: lost); null when not known. */
    moved: z.number().int().nullable(),
  })
  .strict();
export type LastWeek = z.infer<typeof lastWeekSchema>;

export const boardSchema = z
  .object({
    metric: boardMetricSchema,
    /** The viewer's week, Monday to Sunday in their time zone. */
    weekFrom: z.string(),
    weekTo: z.string(),
    /** The top of the board (the world board stops at 100). */
    rows: z.array(boardRowSchema),
    /** The viewer's own row when it is not among `rows`; null when they are not on this board. */
    me: boardRowSchema.nullable(),
    /** Everyone on the board, including those below the top. */
    total: z.number().int().nonnegative(),
    /** Beta 6.2 (C12): null when nobody on it counted anything last week (beta 6.3: and off the week period). */
    lastWeek: lastWeekSchema.nullable(),
    /** Beta 6.3 (C13): the period counted, from its first day to today. */
    period: boardPeriodSchema,
    periodFrom: z.string(),
    periodTo: z.string(),
  })
  .strict();
export type Board = z.infer<typeof boardSchema>;

/** The world board's length. */
export const WORLD_BOARD_ROWS = 100;

/**
 * What counts (ADR-057): a completed gym session with at least 6 sets and
 * 15 minutes, at most one a day; a run recorded by GPS or a watch, at least
 * 500 m, at a pace between 2:50 and 20:00 per km. A typed-in or treadmill run
 * on the phone never counts. The server counts from the synced records; the
 * phone never sends a score.
 */
export const COUNTED_SESSION = { minSets: 6, minSeconds: 15 * 60 } as const;
export const COUNTED_RUN = { minM: 500, fastestSecPerKm: 170, slowestSecPerKm: 1200 } as const;

/* ------------------------------------------------------------ reports -- */

export const REPORT_REASONS = ['handle', 'club-name', 'cheating', 'harassment', 'other'] as const;
export const reportReasonSchema = z.enum(REPORT_REASONS);
export const reportRequestSchema = z
  .object({
    userId: z.string().uuid().optional(),
    clubId: z.string().uuid().optional(),
    reason: reportReasonSchema,
    note: z.string().trim().max(300).optional(),
  })
  .strict()
  .refine((r) => (r.userId === undefined) !== (r.clubId === undefined), 'Report one person or one club.');
export type ReportRequest = z.infer<typeof reportRequestSchema>;

/* -------------------------------------------------------------- admin -- */

export const adminCommunityReportSchema = z
  .object({
    id: z.string().uuid(),
    reason: reportReasonSchema,
    note: z.string().nullable(),
    status: z.enum(['open', 'closed']),
    createdAt: iso,
    reporterHandle: z.string().nullable(),
    target: z
      .object({
        userId: z.string().uuid().nullable(),
        handle: z.string().nullable(),
        hidden: z.boolean().nullable(),
        clubId: z.string().uuid().nullable(),
        clubName: z.string().nullable(),
      })
      .strict(),
  })
  .strict();
export const adminCommunityReportListSchema = z.object({ items: z.array(adminCommunityReportSchema) }).strict();
export const adminCommunityReportQuerySchema = z.object({ status: z.enum(['open', 'closed']).default('open') }).strict();

export const adminCommunityMemberSchema = z
  .object({
    userId: z.string().uuid(),
    handle: z.string(),
    country: z.string().nullable(),
    onWorld: z.boolean(),
    hidden: z.boolean(),
    joinedAt: iso,
  })
  .strict();
export const adminCommunityMemberListSchema = z.object({ items: z.array(adminCommunityMemberSchema), total: z.number().int() }).strict();
export const adminCommunityMemberQuerySchema = z.object({ q: z.string().trim().max(21).optional() }).strict();

/** Hide someone from every board and search, or rename an unsuitable handle (audited). */
export const adminUpdateMemberSchema = z
  .object({ hidden: z.boolean().optional(), handle: handleSchema.optional() })
  .strict()
  .refine((b) => b.hidden !== undefined || b.handle !== undefined, 'Nothing to change.');

export const adminClubSchema = z
  .object({ id: z.string().uuid(), name: z.string(), ownerHandle: z.string().nullable(), members: z.number().int(), createdAt: iso })
  .strict();
export const adminClubListSchema = z.object({ items: z.array(adminClubSchema) }).strict();
export type AdminCommunityReport = z.infer<typeof adminCommunityReportSchema>;
export type AdminCommunityReportList = z.infer<typeof adminCommunityReportListSchema>;
export type AdminCommunityMember = z.infer<typeof adminCommunityMemberSchema>;
export type AdminCommunityMemberList = z.infer<typeof adminCommunityMemberListSchema>;
export type AdminClub = z.infer<typeof adminClubSchema>;
export type AdminClubList = z.infer<typeof adminClubListSchema>;
