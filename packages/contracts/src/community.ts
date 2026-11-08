/**
 * Community (beta 5.8, ADR-057; owner 2026-11-08: "Friends / VIT leaderboard
 * ... dont just focus on VIT we have to make world level"). Opt-in: nobody
 * is seen or found until they join with a handle, and joining is its own
 * consent (`community`, kept in consent_records with the policy version).
 * Boards show counts only: gym sessions and run distance this week, and the
 * streak. Never weights, food, body, readiness, sleep, heart rate or routes.
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

export const communityProfileSchema = z
  .object({
    handle: z.string(),
    avatarId: avatarIdSchema.nullable(),
    country: z.string().nullable(),
    /** On the world board (a separate choice, off by default). */
    onWorld: z.boolean(),
    joinedAt: iso,
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
  .object({ handle: handleSchema.optional(), country: countrySchema.nullable().optional(), onWorld: z.boolean().optional() })
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

/** Clubs one person may make, and join. */
export const MAX_CLUBS_OWNED = 5;
export const MAX_CLUBS_JOINED = 20;
export const MAX_CLUB_MEMBERS = 500;
export const MAX_FRIENDS = 300;

/* ------------------------------------------------------------- boards -- */

/** What a board ranks by: gym sessions (the default) or run distance. */
export const BOARD_METRICS = ['sessions', 'distance'] as const;
export const boardMetricSchema = z.enum(BOARD_METRICS);
export type BoardMetric = z.infer<typeof boardMetricSchema>;

export const boardQuerySchema = z
  .object({ metric: boardMetricSchema.default('sessions'), country: countrySchema.optional() })
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
    me: z.boolean(),
  })
  .strict();
export type BoardRow = z.infer<typeof boardRowSchema>;

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
