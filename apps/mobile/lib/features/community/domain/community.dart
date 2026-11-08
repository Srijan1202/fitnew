/// Beta 5.8 (ADR-057): Community as the server sees it — the member's own
/// profile, other people (a handle, a picture and a country, never more),
/// clubs and the boards. Boards hold counts only: gym sessions and run
/// distance this week, and the streak.
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

/// What a board ranks by.
enum BoardMetric {
  sessions('sessions'),
  distance('distance');

  const BoardMetric(this.wire);
  final String wire;

  static BoardMetric fromWire(String w) =>
      values.firstWhere((m) => m.wire == w, orElse: () => sessions);
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
}

class Board {
  const Board({
    required this.metric,
    required this.weekFrom,
    required this.weekTo,
    required this.rows,
    required this.me,
    required this.total,
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
      );

  final BoardMetric metric;
  final String weekFrom;
  final String weekTo;
  final List<BoardRow> rows;

  /// Your own row when it is below the top; null when you are not on it.
  final BoardRow? me;
  final int total;
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
