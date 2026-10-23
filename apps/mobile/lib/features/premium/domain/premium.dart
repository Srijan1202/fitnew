/// Phase 19 (ADR-027): FITOS Premium as the server sees it (`GET /v1/premium`).
library;

enum PremiumRequestStatus {
  pending('pending'),
  approved('approved'),
  denied('denied');

  const PremiumRequestStatus(this.wire);
  final String wire;

  static PremiumRequestStatus fromWire(String w) =>
      values.firstWhere((s) => s.wire == w);
}

class PremiumRequestInfo {
  const PremiumRequestInfo({
    required this.id,
    required this.status,
    required this.message,
    required this.createdAt,
    required this.decidedAt,
    required this.note,
  });

  factory PremiumRequestInfo.fromJson(Map<String, dynamic> j) =>
      PremiumRequestInfo(
        id: j['id'] as String,
        status: PremiumRequestStatus.fromWire(j['status'] as String),
        message: j['message'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        decidedAt: j['decidedAt'] == null
            ? null
            : DateTime.parse(j['decidedAt'] as String),
        note: j['note'] as String?,
      );

  final String id;
  final PremiumRequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime? decidedAt;

  /// The owner's note with the decision, shown to the user.
  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.wire,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'decidedAt': decidedAt?.toIso8601String(),
        'note': note,
      };
}

class PremiumStatus {
  const PremiumStatus({
    required this.premium,
    required this.source,
    required this.since,
    required this.request,
  });

  factory PremiumStatus.fromJson(Map<String, dynamic> j) => PremiumStatus(
        premium: j['premium'] as bool,
        source: j['source'] as String?,
        since: j['since'] == null ? null : DateTime.parse(j['since'] as String),
        request: j['request'] == null
            ? null
            : PremiumRequestInfo.fromJson(j['request'] as Map<String, dynamic>),
      );

  static const free = PremiumStatus(
    premium: false,
    source: null,
    since: null,
    request: null,
  );

  final bool premium;

  /// 'granted' (approved) or 'admin' (the role); null when not premium.
  final String? source;
  final DateTime? since;
  final PremiumRequestInfo? request;

  bool get pending => request?.status == PremiumRequestStatus.pending;

  Map<String, dynamic> toJson() => {
        'premium': premium,
        'source': source,
        'since': since?.toIso8601String(),
        'request': request?.toJson(),
      };
}

/// What premium unlocks, as the app explains it.
const kPremiumPerks = <(String, String)>[
  (
    'FITOS AI',
    'Chat, Describe your meal and Explain simply, with higher limits.'
  ),
  (
    'Weekly report',
    'Every week on one page: sessions, volume per muscle, records, protein days and your trend weight.'
  ),
  (
    'Themes and app icons',
    'Night, Forest and Ocean themes, and the Gold, Glow and Lime app icons.'
  ),
  (
    'Premium pictures',
    'Crown, Flame and Trophy, and a gold rim around your picture.'
  ),
];
