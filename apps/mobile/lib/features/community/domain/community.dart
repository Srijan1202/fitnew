/// Beta 5.8 (ADR-057): Community as the server sees it — the member's own
/// profile, other people (a handle, a picture and a country, never more),
/// clubs and the boards. Boards hold counts only: gym sessions and run
/// distance this week, and the streak; beta 6.2 adds active days, the plan
/// kept and last week.
library;

/// A handle: 3–20 of a–z, 0–9 and _ (the server checks the rest).
final kHandlePattern = RegExp(r'^[a-z0-9_]{3,20}$');

/// What the person typed, as the server stores it: no @, lower case.
String normalizeHandle(String raw) =>
    raw.trim().replaceFirst(RegExp('^@'), '').toLowerCase();

class CommunityProfile {
  const CommunityProfile({
    required this.handle,
    required this.avatarId,
    required this.country,
    required this.onWorld,
    required this.joinedAt,
  });

  factory CommunityProfile.fromJson(Map<String, dynamic> j) => CommunityProfile(
        handle: j['handle'] as String,
        avatarId: j['avatarId'] as String?,
        country: j['country'] as String?,
        onWorld: j['onWorld'] as bool,
        joinedAt: DateTime.parse(j['joinedAt'] as String),
      );

  final String handle;
  final String? avatarId;
  final String? country;

  /// On the world board: a separate choice, off by default.
  final bool onWorld;
  final DateTime joinedAt;
}

class CommunityMe {
  const CommunityMe({required this.profile, required this.incoming});

  factory CommunityMe.fromJson(Map<String, dynamic> j) => CommunityMe(
        profile: j['profile'] == null
            ? null
            : CommunityProfile.fromJson(j['profile'] as Map<String, dynamic>),
        incoming: (j['incoming'] as num).toInt(),
      );

  /// Null until the person joins.
  final CommunityProfile? profile;

  /// Friend requests waiting for an answer.
  final int incoming;

  bool get joined => profile != null;
}

/// Another member as anyone may see them.
class CommunityPerson {
  const CommunityPerson({
    required this.userId,
    required this.handle,
    required this.avatarId,
    required this.country,
  });

  factory CommunityPerson.fromJson(Map<String, dynamic> j) => CommunityPerson(
        userId: j['userId'] as String,
        handle: j['handle'] as String,
        avatarId: j['avatarId'] as String?,
        country: j['country'] as String?,
      );

  final String userId;
  final String handle;
  final String? avatarId;
  final String? country;
}

class FriendLists {
  const FriendLists({
    required this.friends,
    required this.incoming,
    required this.outgoing,
  });

  factory FriendLists.fromJson(Map<String, dynamic> j) {
    List<CommunityPerson> list(String k) => [
          for (final p in j[k] as List<dynamic>)
            CommunityPerson.fromJson(p as Map<String, dynamic>),
        ];
    return FriendLists(
      friends: list('friends'),
      incoming: list('incoming'),
      outgoing: list('outgoing'),
    );
  }

  final List<CommunityPerson> friends;

  /// Asked you; waiting for your answer.
  final List<CommunityPerson> incoming;

  /// You asked; waiting for theirs.
  final List<CommunityPerson> outgoing;
}

class Club {
  const Club({
    required this.id,
    required this.name,
    required this.code,
    required this.members,
    required this.mine,
  });

  factory Club.fromJson(Map<String, dynamic> j) => Club(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        members: (j['members'] as num).toInt(),
        mine: j['mine'] as bool,
      );

  final String id;
  final String name;

  /// 8 letters and numbers, shown as two fours.
  final String code;
  final int members;

  /// You made it.
  final bool mine;

  String get shownCode =>
      code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;
}

/// What a board ranks by. Beta 6.2 (C11): the streak, active days and
/// the plan kept as well.
enum BoardMetric {
  sessions('sessions', 'Gym sessions'),
  distance('distance', 'Run km'),
  streak('streak', 'Streak'),
  activeDays('active-days', 'Active days'),
  plan('plan', 'Kept my plan');

  const BoardMetric(this.wire, this.label);
  final String wire;
  final String label;

  static BoardMetric fromWire(String w) =>
      values.firstWhere((m) => m.wire == w, orElse: () => sessions);
}

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// The number a board row shows for its metric.
String boardValue(BoardRow r, BoardMetric m) => switch (m) {
      BoardMetric.sessions => _plural(r.sessions, 'session', 'sessions'),
      BoardMetric.distance => kmOf(r.runM),
      BoardMetric.streak => _plural(r.streak, 'day', 'days'),
      BoardMetric.activeDays => _plural(r.activeDays, 'day', 'days'),
      BoardMetric.plan => r.keptPct == null ? '–' : '${r.keptPct}%',
    };

/// The smaller line under a row: what else counted.
String? boardOther(BoardRow r, BoardMetric m) {
  final parts = <String>[
    if (m != BoardMetric.streak && r.streak > 0) '${r.streak}-day streak',
    if (m != BoardMetric.sessions && r.sessions > 0)
      _plural(r.sessions, 'session', 'sessions'),
    if (m != BoardMetric.distance && r.runM > 0) kmOf(r.runM),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// "1st", "2nd", "3rd", "4th"…
String ordinal(int n) {
  final teen = n % 100 >= 11 && n % 100 <= 13;
  final suffix = teen
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$n$suffix';
}

/// Beta 6.2 (C12): last week on a board.
class LastWeek {
  const LastWeek({
    required this.weekFrom,
    required this.podium,
    required this.myRank,
    required this.moved,
  });

  factory LastWeek.fromJson(Map<String, dynamic> j) => LastWeek(
        weekFrom: j['weekFrom'] as String,
        podium: [
          for (final r in j['podium'] as List<dynamic>)
            BoardRow.fromJson(r as Map<String, dynamic>),
        ],
        myRank: (j['myRank'] as num?)?.toInt(),
        moved: (j['moved'] as num?)?.toInt(),
      );

  final String weekFrom;

  /// The top three (ties share a place).
  final List<BoardRow> podium;

  /// Your place last week; null when you were not on it.
  final int? myRank;

  /// Places gained since the week before (negative: lost).
  final int? moved;

  /// "You were 3rd last week · up 2", or null.
  String? get myLine {
    final rank = myRank;
    if (rank == null) return null;
    final m = moved;
    final change = m == null || m == 0
        ? ''
        : m > 0
            ? ' · up $m'
            : ' · down ${-m}';
    return 'You were ${ordinal(rank)} last week$change';
  }
}

/// Beta 6.2 (C4): one week's counts on a profile.
class WeekCounts {
  const WeekCounts({
    required this.weekFrom,
    required this.sessions,
    required this.runM,
    required this.activeDays,
    required this.keptPct,
  });

  factory WeekCounts.fromJson(Map<String, dynamic> j) => WeekCounts(
        weekFrom: j['weekFrom'] as String,
        sessions: (j['sessions'] as num).toInt(),
        runM: (j['runM'] as num).toInt(),
        activeDays: (j['activeDays'] as num).toInt(),
        keptPct: (j['keptPct'] as num?)?.toInt(),
      );

  final String weekFrom;
  final int sessions;
  final int runM;
  final int activeDays;

  /// Sessions done of those planned, in per cent; null without a plan.
  final int? keptPct;
}

/// Beta 6.2 (C4, owner 2026-11-11): a friend's or club-mate's board data.
class PersonProfile {
  const PersonProfile({
    required this.person,
    required this.friend,
    required this.friendsSince,
    required this.streak,
    required this.thisWeek,
    required this.weeks,
    required this.clubsInCommon,
  });

  factory PersonProfile.fromJson(Map<String, dynamic> j) => PersonProfile(
        person: CommunityPerson.fromJson(j['person'] as Map<String, dynamic>),
        friend: j['relation'] == 'friend',
        friendsSince: j['friendsSince'] == null
            ? null
            : DateTime.parse(j['friendsSince'] as String),
        streak: (j['streak'] as num).toInt(),
        thisWeek: WeekCounts.fromJson(j['thisWeek'] as Map<String, dynamic>),
        weeks: [
          for (final w in j['weeks'] as List<dynamic>)
            WeekCounts.fromJson(w as Map<String, dynamic>),
        ],
        clubsInCommon: [
          for (final c in j['clubsInCommon'] as List<dynamic>)
            (
              id: (c as Map<String, dynamic>)['id'] as String,
              name: c['name'] as String,
            ),
        ],
      );

  final CommunityPerson person;

  /// A friend; otherwise someone in a club with you.
  final bool friend;
  final DateTime? friendsSince;
  final int streak;
  final WeekCounts thisWeek;

  /// The weeks before this one, oldest first.
  final List<WeekCounts> weeks;
  final List<({String id, String name})> clubsInCommon;
}

/// Beta 6.2 (C8, C15, owner Q1): the links that open FITOS (Android App Links).
String clubInviteUrl(String code) => 'https://tryfitos.me/c/$code';
String friendInviteUrl(String handle) => 'https://tryfitos.me/u/$handle';

/// What an opened link asks for.
sealed class InviteLink {
  const InviteLink();

  /// A tryfitos.me club or friend link; null for anything else.
  static InviteLink? parse(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'https' || uri.host != 'tryfitos.me') {
      return null;
    }
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.length != 2) return null;
    if (parts[0] == 'c') {
      final code = parts[1].toUpperCase();
      return RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)
          ? ClubInvite(code)
          : null;
    }
    if (parts[0] == 'u') {
      final handle = parts[1].toLowerCase();
      return kHandlePattern.hasMatch(handle) ? FriendInvite(handle) : null;
    }
    return null;
  }
}

class ClubInvite extends InviteLink {
  const ClubInvite(this.code);
  final String code;
}

class FriendInvite extends InviteLink {
  const FriendInvite(this.handle);
  final String handle;
}

class BoardRow {
  const BoardRow({
    required this.rank,
    required this.userId,
    required this.handle,
    required this.avatarId,
    required this.country,
    required this.sessions,
    required this.runM,
    required this.streak,
    required this.me,
    this.activeDays = 0,
    this.keptPct,
  });

  factory BoardRow.fromJson(Map<String, dynamic> j) => BoardRow(
        rank: (j['rank'] as num).toInt(),
        userId: j['userId'] as String,
        handle: j['handle'] as String,
        avatarId: j['avatarId'] as String?,
        country: j['country'] as String?,
        sessions: (j['sessions'] as num).toInt(),
        runM: (j['runM'] as num).toInt(),
        streak: (j['streak'] as num).toInt(),
        me: j['me'] as bool,
        activeDays: (j['activeDays'] as num?)?.toInt() ?? 0,
        keptPct: (j['keptPct'] as num?)?.toInt(),
      );

  final int rank;
  final String userId;
  final String handle;
  final String? avatarId;
  final String? country;
  final int sessions;
  final int runM;
  final int streak;
  final bool me;

  /// Beta 6.2: days this week with a counted session or run.
  final int activeDays;

  /// Beta 6.2: sessions done of those planned up to today; null without a plan.
  final int? keptPct;
}

class Board {
  const Board({
    required this.metric,
    required this.weekFrom,
    required this.weekTo,
    required this.rows,
    required this.me,
    required this.total,
    this.lastWeek,
  });

  factory Board.fromJson(Map<String, dynamic> j) => Board(
        metric: BoardMetric.fromWire(j['metric'] as String),
        weekFrom: j['weekFrom'] as String,
        weekTo: j['weekTo'] as String,
        rows: [
          for (final r in j['rows'] as List<dynamic>)
            BoardRow.fromJson(r as Map<String, dynamic>),
        ],
        me: j['me'] == null
            ? null
            : BoardRow.fromJson(j['me'] as Map<String, dynamic>),
        total: (j['total'] as num).toInt(),
        lastWeek: j['lastWeek'] == null
            ? null
            : LastWeek.fromJson(j['lastWeek'] as Map<String, dynamic>),
      );

  final BoardMetric metric;
  final String weekFrom;
  final String weekTo;
  final List<BoardRow> rows;

  /// Your own row when it is below the top; null when you are not on it.
  final BoardRow? me;
  final int total;

  /// Beta 6.2 (C12): null when nobody here counted anything last week.
  final LastWeek? lastWeek;
}

/// Why a report is made.
enum ReportReason {
  handle('handle', 'Their handle'),
  clubName('club-name', 'The club name'),
  cheating('cheating', 'Cheating'),
  harassment('harassment', 'Harassment'),
  other('other', 'Something else');

  const ReportReason(this.wire, this.label);
  final String wire;
  final String label;
}

/// The flag of an ISO country code, from its regional indicator letters.
String flagOf(String? code) {
  if (code == null || code.length != 2) return '';
  final a = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final b = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCodes([a, b]);
}

/// "12.4 km" from metres.
String kmOf(int metres) {
  final km = metres / 1000;
  return '${km >= 100 ? km.toStringAsFixed(0) : km.toStringAsFixed(1)} km';
}

/// ISO 3166-1 alpha-2 codes with English names (the same list as the
/// contracts' COUNTRIES; a test keeps them in step).
const kCountries = <String, String>{
  'AD': 'Andorra',
  'AE': 'United Arab Emirates',
  'AF': 'Afghanistan',
  'AG': 'Antigua & Barbuda',
  'AI': 'Anguilla',
  'AL': 'Albania',
  'AM': 'Armenia',
  'AO': 'Angola',
  'AQ': 'Antarctica',
  'AR': 'Argentina',
  'AS': 'American Samoa',
  'AT': 'Austria',
  'AU': 'Australia',
  'AW': 'Aruba',
  'AX': 'Åland Islands',
  'AZ': 'Azerbaijan',
  'BA': 'Bosnia & Herzegovina',
  'BB': 'Barbados',
  'BD': 'Bangladesh',
  'BE': 'Belgium',
  'BF': 'Burkina Faso',
  'BG': 'Bulgaria',
  'BH': 'Bahrain',
  'BI': 'Burundi',
  'BJ': 'Benin',
  'BL': 'St. Barthélemy',
  'BM': 'Bermuda',
  'BN': 'Brunei',
  'BO': 'Bolivia',
  'BQ': 'Caribbean Netherlands',
  'BR': 'Brazil',
  'BS': 'Bahamas',
  'BT': 'Bhutan',
  'BV': 'Bouvet Island',
  'BW': 'Botswana',
  'BY': 'Belarus',
  'BZ': 'Belize',
  'CA': 'Canada',
  'CC': 'Cocos (Keeling) Islands',
  'CD': 'Congo - Kinshasa',
  'CF': 'Central African Republic',
  'CG': 'Congo - Brazzaville',
  'CH': 'Switzerland',
  'CI': 'Côte d’Ivoire',
  'CK': 'Cook Islands',
  'CL': 'Chile',
  'CM': 'Cameroon',
  'CN': 'China',
  'CO': 'Colombia',
  'CR': 'Costa Rica',
  'CU': 'Cuba',
  'CV': 'Cape Verde',
  'CW': 'Curaçao',
  'CX': 'Christmas Island',
  'CY': 'Cyprus',
  'CZ': 'Czechia',
  'DE': 'Germany',
  'DJ': 'Djibouti',
  'DK': 'Denmark',
  'DM': 'Dominica',
  'DO': 'Dominican Republic',
  'DY': 'Benin',
  'DZ': 'Algeria',
  'EC': 'Ecuador',
  'EE': 'Estonia',
  'EG': 'Egypt',
  'EH': 'Western Sahara',
  'ER': 'Eritrea',
  'ES': 'Spain',
  'ET': 'Ethiopia',
  'FI': 'Finland',
  'FJ': 'Fiji',
  'FK': 'Falkland Islands',
  'FM': 'Micronesia',
  'FO': 'Faroe Islands',
  'FR': 'France',
  'GA': 'Gabon',
  'GB': 'United Kingdom',
  'GD': 'Grenada',
  'GE': 'Georgia',
  'GF': 'French Guiana',
  'GG': 'Guernsey',
  'GH': 'Ghana',
  'GI': 'Gibraltar',
  'GL': 'Greenland',
  'GM': 'Gambia',
  'GN': 'Guinea',
  'GP': 'Guadeloupe',
  'GQ': 'Equatorial Guinea',
  'GR': 'Greece',
  'GS': 'South Georgia & South Sandwich Islands',
  'GT': 'Guatemala',
  'GU': 'Guam',
  'GW': 'Guinea-Bissau',
  'GY': 'Guyana',
  'HK': 'Hong Kong SAR China',
  'HM': 'Heard & McDonald Islands',
  'HN': 'Honduras',
  'HR': 'Croatia',
  'HT': 'Haiti',
  'HU': 'Hungary',
  'HV': 'Burkina Faso',
  'ID': 'Indonesia',
  'IE': 'Ireland',
  'IL': 'Israel',
  'IM': 'Isle of Man',
  'IN': 'India',
  'IO': 'British Indian Ocean Territory',
  'IQ': 'Iraq',
  'IR': 'Iran',
  'IS': 'Iceland',
  'IT': 'Italy',
  'JE': 'Jersey',
  'JM': 'Jamaica',
  'JO': 'Jordan',
  'JP': 'Japan',
  'KE': 'Kenya',
  'KG': 'Kyrgyzstan',
  'KH': 'Cambodia',
  'KI': 'Kiribati',
  'KM': 'Comoros',
  'KN': 'St. Kitts & Nevis',
  'KP': 'North Korea',
  'KR': 'South Korea',
  'KW': 'Kuwait',
  'KY': 'Cayman Islands',
  'KZ': 'Kazakhstan',
  'LA': 'Laos',
  'LB': 'Lebanon',
  'LC': 'St. Lucia',
  'LI': 'Liechtenstein',
  'LK': 'Sri Lanka',
  'LR': 'Liberia',
  'LS': 'Lesotho',
  'LT': 'Lithuania',
  'LU': 'Luxembourg',
  'LV': 'Latvia',
  'LY': 'Libya',
  'MA': 'Morocco',
  'MC': 'Monaco',
  'MD': 'Moldova',
  'ME': 'Montenegro',
  'MF': 'St. Martin',
  'MG': 'Madagascar',
  'MH': 'Marshall Islands',
  'MK': 'North Macedonia',
  'ML': 'Mali',
  'MM': 'Myanmar (Burma)',
  'MN': 'Mongolia',
  'MO': 'Macao SAR China',
  'MP': 'Northern Mariana Islands',
  'MQ': 'Martinique',
  'MR': 'Mauritania',
  'MS': 'Montserrat',
  'MT': 'Malta',
  'MU': 'Mauritius',
  'MV': 'Maldives',
  'MW': 'Malawi',
  'MX': 'Mexico',
  'MY': 'Malaysia',
  'MZ': 'Mozambique',
  'NA': 'Namibia',
  'NC': 'New Caledonia',
  'NE': 'Niger',
  'NF': 'Norfolk Island',
  'NG': 'Nigeria',
  'NH': 'Vanuatu',
  'NI': 'Nicaragua',
  'NL': 'Netherlands',
  'NO': 'Norway',
  'NP': 'Nepal',
  'NR': 'Nauru',
  'NU': 'Niue',
  'NZ': 'New Zealand',
  'OM': 'Oman',
  'PA': 'Panama',
  'PE': 'Peru',
  'PF': 'French Polynesia',
  'PG': 'Papua New Guinea',
  'PH': 'Philippines',
  'PK': 'Pakistan',
  'PL': 'Poland',
  'PM': 'St. Pierre & Miquelon',
  'PN': 'Pitcairn Islands',
  'PR': 'Puerto Rico',
  'PS': 'Palestinian Territories',
  'PT': 'Portugal',
  'PW': 'Palau',
  'PY': 'Paraguay',
  'QA': 'Qatar',
  'RE': 'Réunion',
  'RH': 'Zimbabwe',
  'RO': 'Romania',
  'RS': 'Serbia',
  'RU': 'Russia',
  'RW': 'Rwanda',
  'SA': 'Saudi Arabia',
  'SB': 'Solomon Islands',
  'SC': 'Seychelles',
  'SD': 'Sudan',
  'SE': 'Sweden',
  'SG': 'Singapore',
  'SH': 'St. Helena',
  'SI': 'Slovenia',
  'SJ': 'Svalbard & Jan Mayen',
  'SK': 'Slovakia',
  'SL': 'Sierra Leone',
  'SM': 'San Marino',
  'SN': 'Senegal',
  'SO': 'Somalia',
  'SR': 'Suriname',
  'SS': 'South Sudan',
  'ST': 'São Tomé & Príncipe',
  'SV': 'El Salvador',
  'SX': 'Sint Maarten',
  'SY': 'Syria',
  'SZ': 'Eswatini',
  'TC': 'Turks & Caicos Islands',
  'TD': 'Chad',
  'TF': 'French Southern Territories',
  'TG': 'Togo',
  'TH': 'Thailand',
  'TJ': 'Tajikistan',
  'TK': 'Tokelau',
  'TL': 'Timor-Leste',
  'TM': 'Turkmenistan',
  'TN': 'Tunisia',
  'TO': 'Tonga',
  'TR': 'Türkiye',
  'TT': 'Trinidad & Tobago',
  'TV': 'Tuvalu',
  'TW': 'Taiwan',
  'TZ': 'Tanzania',
  'UA': 'Ukraine',
  'UG': 'Uganda',
  'UK': 'United Kingdom',
  'UM': 'U.S. Outlying Islands',
  'US': 'United States',
  'UY': 'Uruguay',
  'UZ': 'Uzbekistan',
  'VA': 'Vatican City',
  'VC': 'St. Vincent & Grenadines',
  'VD': 'Vietnam',
  'VE': 'Venezuela',
  'VG': 'British Virgin Islands',
  'VI': 'U.S. Virgin Islands',
  'VN': 'Vietnam',
  'VU': 'Vanuatu',
  'WF': 'Wallis & Futuna',
  'WS': 'Samoa',
  'XK': 'Kosovo',
  'YE': 'Yemen',
  'YT': 'Mayotte',
  'ZA': 'South Africa',
  'ZM': 'Zambia',
  'ZW': 'Zimbabwe',
};
