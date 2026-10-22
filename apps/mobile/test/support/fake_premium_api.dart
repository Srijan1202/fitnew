import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/premium/data/premium_api.dart';
import 'package:fitos/features/premium/domain/avatars.dart';
import 'package:fitos/features/premium/domain/premium.dart';
import 'package:fitos/features/progress/data/weekly_report_api.dart';

/// A scripted premium server (Phase 19, ADR-027). Free unless a test says;
/// a request is pending until the test approves it.
class FakePremiumApi implements PremiumApi {
  FakePremiumApi({this.premium = false});

  bool premium;
  PremiumRequestInfo? latest;
  String? avatarId;
  final calls = <String>[];

  void approve({String? note}) {
    premium = true;
    latest = PremiumRequestInfo(
      id: 'req-1',
      status: PremiumRequestStatus.approved,
      message: latest?.message,
      createdAt: DateTime.utc(2026, 10, 22),
      decidedAt: DateTime.utc(2026, 10, 22, 1),
      note: note,
    );
  }

  @override
  Future<Result<PremiumStatus>> status() async {
    calls.add('status');
    return Ok(
      PremiumStatus(
        premium: premium,
        source: premium ? 'granted' : null,
        since: premium ? DateTime.utc(2026, 10, 22) : null,
        request: latest,
      ),
    );
  }

  @override
  Future<Result<PremiumRequestInfo>> request({String? message}) async {
    calls.add('request:${message ?? ''}');
    if (premium || latest?.status == PremiumRequestStatus.pending) {
      return const Err(
        Conflict('Your request is already waiting for an answer.'),
      );
    }
    latest = PremiumRequestInfo(
      id: 'req-1',
      status: PremiumRequestStatus.pending,
      message: message == null || message.isEmpty ? null : message,
      createdAt: DateTime.utc(2026, 10, 22),
      decidedAt: null,
      note: null,
    );
    return Ok(latest!);
  }

  @override
  Future<Result<String?>> setAvatar(String? id) async {
    calls.add('avatar:$id');
    if (avatarById(id)?.premium == true && !premium) {
      return const Err(
        Forbidden(
          'This picture is part of FITOS Premium.',
          issue: 'premium-required',
        ),
      );
    }
    avatarId = id;
    return Ok(id);
  }
}

/// A scripted weekly report (Phase 19).
class FakeWeeklyReportApi implements WeeklyReportApi {
  final asked = <String?>[];

  @override
  Future<Result<WeeklyReport>> report({String? week}) async {
    asked.add(week);
    const weeks = ['2026-W40', '2026-W41', '2026-W42', '2026-W43'];
    final w = week ?? weeks.last;
    return Ok(
      WeeklyReport.fromJson({
        'isoWeek': w,
        'from': '2026-10-19',
        'to': '2026-10-25',
        'complete': w != weeks.last,
        'weeks': weeks,
        'training': {'completed': 3, 'planned': 4, 'percent': 75},
        'volume': {
          'totalHardSets': 51,
          'productive': ['chest'],
          'below': ['calves'],
          'above': <String>[],
        },
        'prs': {
          'count': 1,
          'lifts': ['Bench Press'],
        },
        'nutrition': {
          'loggedDays': 5,
          'judgedDays': 5,
          'proteinMet': 4,
          'caloriesOn': 3,
        },
        'weight': {'startKg': 70.8, 'endKg': 70.4, 'changeKg': -0.4},
        'highlights': ['3 of 4 planned sessions.', 'Trend weight down 0.4 kg.'],
      }),
    );
  }
}
