import '../../../../core/errors/result.dart';
import '../entities/food.dart';

/// The food library (Phase 7): search the server's foods and add your own
/// from a label. Ranking, spelling variants and who sees which food are the
/// server's; the client sends the text and renders the answer. There is no
/// logging here — that is Phase 8.
abstract class FoodRepository {
  Future<Result<List<FoodSearchResult>>> search(String q, {int limit = 20});

  /// Retry-safe: the same `clientFoodId` always returns the same food.
  Future<Result<Food>> create(CreateFoodRequest request);

  /// Beta 3.2 (ADR-032): a search that found nothing, or "Ask us to add it"
  /// ([asked]). Counted anonymously by the server.
  Future<Result<void>> reportMissing(String query, {bool asked = false});
}
