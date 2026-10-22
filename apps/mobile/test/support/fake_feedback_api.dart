import 'package:fitos/core/config/app_config.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/feedback/data/feedback_api.dart';

/// A scripted `POST /v1/feedback` (Phase 19).
class FakeFeedbackApi implements FeedbackApi {
  final sent =
      <({FeedbackCategory category, String message, String appVersion})>[];

  /// The next send fails with this, when set.
  Failure? nextFailure;

  @override
  Future<Result<void>> send({
    required FeedbackCategory category,
    required String message,
    required String appVersion,
  }) async {
    final f = nextFailure;
    if (f != null) {
      nextFailure = null;
      return Err(f);
    }
    sent.add((category: category, message: message, appVersion: appVersion));
    return const Ok(null);
  }
}

/// A scripted `GET /v1/meta/config` (Phase 19). Null = unreachable.
class FakeMetaApi implements MetaApi {
  FakeMetaApi({this.minimumBuild = 0, this.flags = const {}});

  int minimumBuild;
  Map<String, bool> flags;
  bool offline = false;

  @override
  Future<AppConfig?> config() async =>
      offline ? null : AppConfig(flags: flags, minimumBuild: minimumBuild);
}
