import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/food_repository_impl.dart';
import '../../domain/entities/food.dart';
import '../../domain/repositories/food_repository.dart';

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
    return result.when(ok: (r) => r, err: (f) => throw f);
  },
  // No silent retry-with-backoff: a failure is shown with "Try again" (§6.6).
  retry: (_, __) => null,
);
