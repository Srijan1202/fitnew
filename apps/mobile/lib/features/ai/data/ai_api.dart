import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/ai.dart';
import '../domain/entities/ai_draft.dart';

/// `/v1/ai/*` — FITOS AI lives on the server (owner B2); the phone asks and
/// shows. No model key exists on the phone, by design.
abstract class AiApi {
  Future<Result<AiStatus>> status();
  Future<Result<AiChatResponse>> chat(AiChatRequest request);

  /// Phase 14: a meal in the user's words → a draft to confirm. Nothing is
  /// logged by this call.
  Future<Result<ParseFoodResponse>> parseFood(String text);

  /// Phase 14: a TODAY action's reason in plainer words, or the engine's own.
  Future<Result<ExplainResponse>> explain(String actionId);
}

class DioAiApi implements AiApi {
  DioAiApi(this._dio);

  final Dio _dio;

  Future<Result<T>> _guard<T>(
    Future<Response<Map<String, dynamic>>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final data = (await call()).data;
      if (data == null) return const Err(Unknown());
      return Ok(parse(data));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }

  /// Wire encoder, public for the conformance test.
  static Map<String, dynamic> chatJson(AiChatRequest r) => {
        'message': r.message,
        'history': [
          for (final m in r.history)
            {'role': m.role.wire, 'content': m.content},
        ],
      };

  @override
  Future<Result<AiStatus>> status() => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/ai/status'),
        AiStatus.fromJson,
      );

  @override
  Future<Result<AiChatResponse>> chat(AiChatRequest request) => _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/ai/chat',
          data: chatJson(request),
          // A model call with tools can take a while; longer than the default.
          options: Options(receiveTimeout: const Duration(seconds: 60)),
        ),
        AiChatResponse.fromJson,
      );

  @override
  Future<Result<ParseFoodResponse>> parseFood(String text) => _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/nutrition/parse',
          data: {'text': text},
          options: Options(receiveTimeout: const Duration(seconds: 30)),
        ),
        ParseFoodResponse.fromJson,
      );

  @override
  Future<Result<ExplainResponse>> explain(String actionId) => _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/ai/explain',
          data: {'actionId': actionId},
          options: Options(receiveTimeout: const Duration(seconds: 30)),
        ),
        ExplainResponse.fromJson,
      );
}
