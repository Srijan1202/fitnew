import 'dart:typed_data';

import 'package:fitos/core/config/app_config.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/feedback/data/feedback_api.dart';

/// A scripted `POST /v1/feedback` (Phase 19); beta 3.6: the person's
/// messages and replies, and marking them read.
class FakeFeedbackApi implements FeedbackApi {
  final sent = <({
    FeedbackCategory category,
    String message,
    String appVersion,
    FeedbackDevice? device,
    List<Uint8List> pictures,
  })>[];

  /// The next send fails with this, when set.
  Failure? nextFailure;

  /// What `GET /feedback/mine` answers; null = offline.
  MyFeedbackList? mineList = const MyFeedbackList(items: [], unread: 0);
  int markReadCalls = 0;

  @override
  Future<Result<void>> send({
    required FeedbackCategory category,
    required String message,
    required String appVersion,
    FeedbackDevice? device,
    List<Uint8List> pictures = const [],
  }) async {
    final f = nextFailure;
    if (f != null) {
      nextFailure = null;
      return Err(f);
    }
    sent.add(
      (
        category: category,
        message: message,
        appVersion: appVersion,
        device: device,
        pictures: List.of(pictures),
      ),
    );
    return const Ok(null);
  }

  @override
  Future<Result<MyFeedbackList>> mine() async {
    final m = mineList;
    return m == null ? const Err(Offline()) : Ok(m);
  }

  @override
  Future<Result<void>> markRead() async {
    markReadCalls++;
    final m = mineList;
    if (m != null) mineList = MyFeedbackList(items: m.items, unread: 0);
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
