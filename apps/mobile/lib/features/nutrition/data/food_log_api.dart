import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/food_log.dart';

/// The Phase 8 nutrition endpoints. Envelope mapping only; the auth header is
/// the interceptor's. Everything is the server's — this never computes.
abstract class FoodLogApi {
  Future<Result<NutritionDay>> today();
  Future<Result<NutritionDay>> day(String date);
  Future<Result<CreateLogResponse>> createLog(CreateLogRequest request);
  Future<Result<DeleteLogResponse>> deleteLog(String clientLogId);
  Future<Result<List<RecentFood>>> recentFoods({int limit = 20});
  Future<Result<List<SavedMeal>>> savedMeals();
  Future<Result<SavedMeal>> createSavedMeal(CreateSavedMealRequest request);
  Future<Result<void>> deleteSavedMeal(String id);
}

class DioFoodLogApi implements FoodLogApi {
  DioFoodLogApi(this._dio);

  final Dio _dio;

  Future<Result<T>> _guard<T>(
    Future<Response<Map<String, dynamic>>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await call();
      final data = response.data;
      if (data == null) return const Err(Unknown());
      return Ok(parse(data));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }

  @override
  Future<Result<NutritionDay>> today() => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/nutrition/today'),
        NutritionDay.fromJson,
      );

  @override
  Future<Result<NutritionDay>> day(String date) => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/nutrition/day/$date'),
        NutritionDay.fromJson,
      );

  @override
  Future<Result<CreateLogResponse>> createLog(CreateLogRequest request) =>
      _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/nutrition/logs',
          data: request.toJson(),
        ),
        CreateLogResponse.fromJson,
      );

  @override
  Future<Result<DeleteLogResponse>> deleteLog(String clientLogId) => _guard(
        () => _dio.delete<Map<String, dynamic>>(
          '/v1/nutrition/logs/$clientLogId',
        ),
        DeleteLogResponse.fromJson,
      );

  @override
  Future<Result<List<RecentFood>>> recentFoods({int limit = 20}) => _guard(
        () => _dio.get<Map<String, dynamic>>(
          '/v1/nutrition/foods/recent',
          queryParameters: <String, String>{'limit': '$limit'},
        ),
        (json) => RecentFoodsResponse.fromJson(json).items,
      );

  @override
  Future<Result<List<SavedMeal>>> savedMeals() => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/nutrition/saved-meals'),
        (json) => (json['items'] as List<dynamic>)
            .map((e) => SavedMeal.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  Future<Result<SavedMeal>> createSavedMeal(CreateSavedMealRequest request) =>
      _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/nutrition/saved-meals',
          data: request.toJson(),
        ),
        SavedMeal.fromJson,
      );

  @override
  Future<Result<void>> deleteSavedMeal(String id) async {
    try {
      await _dio.delete<void>('/v1/nutrition/saved-meals/$id');
      return const Ok(null);
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }
}
