import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/food_repository_impl.dart';
import '../../domain/entities/food.dart';
import '../../domain/repositories/food_repository.dart';
import '../../../../core/config/app_features.dart';

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return DioFoodRepository(ref.watch(dioProvider));
});

/// The library's search text. Pure client state; a change re-asks the server.
class FoodQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String q) => state = q.trim();

  void clear() => state = '';
}

final foodQueryProvider = NotifierProvider<FoodQuery, String>(FoodQuery.new);

/// Results for the current text, or null before anything is typed. Every
/// change is a request: ranking and spelling variants are the server's, and
/// nothing is cached for offline use (Phase 7 has no offline food cache).
final foodSearchProvider = FutureProvider<List<FoodSearchResult>?>(
  (ref) async {
    final q = ref.watch(foodQueryProvider);
    if (q.isEmpty) return null;
    final result = await ref.read(foodRepositoryProvider).search(q);
    final items = result.when(ok: (r) => r, err: (f) => throw f);
    if (items.isEmpty) ref.read(missingFoodReporterProvider).foundNothing(q);
    return items;
  },
  // No silent retry-with-backoff: a failure is shown with "Try again" (§6.6).
  retry: (_, __) => null,
);

/// Beta 3.2 (ADR-032): searches that found nothing go to the server's list
/// of missing foods (anonymously; the server counts each person once a
/// day). Each text is reported once per app session, quietly: a failure is
/// never shown.
class MissingFoodReporter {
  MissingFoodReporter(this._repo, {bool Function()? enabled})
      : _enabled = enabled ?? (() => true);

  final FoodRepository _repo;

  /// Beta 3.3 (ADR-033): the admin's `food-requests` switch.
  final bool Function() _enabled;
  final Set<String> _sent = <String>{};

  static String _key(String q) => q.trim().toLowerCase();

  void foundNothing(String query) {
    final key = _key(query);
    if (!_enabled() || key.length < 2 || !_sent.add(key)) return;
    unawaited(_repo.reportMissing(query.trim()));
  }

  /// "Ask us to add it": true once the server has it.
  Future<bool> ask(String query) async {
    final r = await _repo.reportMissing(query.trim(), asked: true);
    return r.when(ok: (_) => true, err: (_) => false);
  }
}

final missingFoodReporterProvider = Provider<MissingFoodReporter>(
  (ref) => MissingFoodReporter(
    ref.watch(foodRepositoryProvider),
    enabled: () => ref.read(featureOnProvider(AppFeature.foodRequests)),
  ),
);
