import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/food.dart';
import '../domain/repositories/food_repository.dart';

/// Two calls, envelope mapping, nothing else. Auth header is the interceptor's.
class DioFoodRepository implements FoodRepository {
  DioFoodRepository(this._dio);

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
  Future<Result<List<FoodSearchResult>>> search(String q, {int limit = 20}) =>
      _guard(
        () => _dio.get<Map<String, dynamic>>(
          '/v1/nutrition/foods/search',
          queryParameters: <String, String>{'q': q, 'limit': '$limit'},
        ),
        (json) => FoodSearchResponse.fromJson(json).items,
      );

  @override
  Future<Result<Food>> create(CreateFoodRequest request) => _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/nutrition/foods',
          data: request.toJson(),
        ),
        Food.fromJson,
      );
}
