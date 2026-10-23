import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/progress_photos.dart';
import '../../domain/progress.dart';
import '../progress_providers.dart';

/// Beta 3.4 (ADR-035): progress photos, on this phone only.
final photoSourceProvider =
    Provider<PhotoSource>((_) => const DevicePhotoSource());

/// The folder for an account (a temp folder in tests).
final photoDirProvider =
    Provider<Future<Directory> Function(String account)>((_) => photoDirFor);

class ProgressPhotosController extends AsyncNotifier<List<ProgressPhoto>> {
  Future<PhotoStore?> _store() async {
    final account = ref.read(sessionUserIdProvider);
    if (account == null) return null;
    return PhotoStore(await ref.read(photoDirProvider)(account));
  }

  @override
  Future<List<ProgressPhoto>> build() async {
    ref.watch(sessionUserIdProvider);
    final store = await _store();
    return store == null ? const [] : store.list();
  }

  /// Adds a picked photo; the weight is the trend for that day when known.
  Future<void> add({
    required String source,
    required String date,
    required PhotoPose pose,
  }) async {
    final store = await _store();
    if (store == null) return;
    await store.add(
      source: source,
      date: date,
      pose: pose,
      weightKg: _trendOn(date),
    );
    state = AsyncData(await store.list());
  }

  Future<void> delete(String id) async {
    final store = await _store();
    if (store == null) return;
    await store.delete(id);
    state = AsyncData(await store.list());
  }

  /// The trend weight on [date], or the latest within a week before it, from
  /// what Progress already shows; null when it is not known here.
  double? _trendOn(String date) {
    final summary = ref
        .read(progressSummaryProvider(ref.read(progressWindowProvider)))
        .value
        ?.summary;
    return trendNear(summary?.weight.points ?? const [], date);
  }
}

/// The trend on [date], or the closest earlier one within 7 days.
double? trendNear(List<WeightPoint> points, String date) {
  WeightPoint? best;
  for (final pt in points) {
    if (pt.date.compareTo(date) > 0) continue;
    final days =
        DateTime.parse(date).difference(DateTime.parse(pt.date)).inDays;
    if (days > 7) continue;
    if (best == null || pt.date.compareTo(best.date) > 0) best = pt;
  }
  return best?.trendKg;
}

final progressPhotosProvider =
    AsyncNotifierProvider<ProgressPhotosController, List<ProgressPhoto>>(
  ProgressPhotosController.new,
);

/// Deletes every photo of an account on this phone (account deletion).
final accountPhotoEraserProvider = Provider<Future<void> Function(String)>(
  (ref) => (account) async =>
      PhotoStore(await ref.read(photoDirProvider)(account)).deleteAll(),
);
