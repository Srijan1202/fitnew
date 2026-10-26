import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/ai.dart';
import '../domain/entities/ai_draft.dart';
import '../domain/entities/food_guide.dart';

/// `/v1/ai/*` — FITOS AI lives on the server (owner B2); the phone asks and
/// shows. No model key exists on the phone, by design.
abstract class AiApi {
  Future<Result<AiStatus>> status();
  Future<Result<AiChatResponse>> chat(AiChatRequest request);

  /// Beta 3.8: the same chat, the answer arriving as it is written. Always
  /// ends with [AiStreamDone] or [AiStreamFailed].
  Stream<AiStreamEvent> chatStream(AiChatRequest request);

  /// Phase 14: a meal in the user's words → a draft to confirm. Nothing is
  /// logged by this call.
  Future<Result<ParseFoodResponse>> parseFood(String text);

  /// Phase 14: a TODAY action's reason in plainer words, or the engine's own.
  Future<Result<ExplainResponse>> explain(String actionId);

  /// Beta 3.6: "What should I eat?" — plates for one meal of today. Nothing
  /// is logged by this call.
  Future<Result<FoodGuideResponse>> foodGuide(FoodGuideRequest request);
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
  Stream<AiStreamEvent> chatStream(AiChatRequest request) async* {
    final Response<ResponseBody> res;
    try {
      res = await _dio.post<ResponseBody>(
        '/v1/ai/chat/stream',
        data: chatJson(request),
        options: Options(
          responseType: ResponseType.stream,
          headers: {'accept': 'text/event-stream'},
          // Between two pieces of the answer, not for the whole of it.
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
    } on DioException catch (e) {
      final failure = await _streamFailure(e);
      if (failure is NotFound) {
        // A server from before beta 3.8: ask the old way, answer whole.
        final r = await chat(request);
        yield r.when(ok: AiStreamDone.new, err: AiStreamFailed.new);
        return;
      }
      yield AiStreamFailed(failure);
      return;
    }
    var event = '';
    final data = StringBuffer();
    try {
      await for (final line in res.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data.write(line.substring(5).trim());
        } else if (line.isEmpty && event.isNotEmpty) {
          final json = jsonDecode(data.toString()) as Map<String, dynamic>;
          final name = event;
          event = '';
          data.clear();
          switch (name) {
            case 'text':
              yield AiStreamText(json['text'] as String);
            case 'tool':
              yield const AiStreamTool();
            case 'done':
              yield AiStreamDone(AiChatResponse.fromJson(json));
              return;
            case 'error':
              yield AiStreamFailed(ErrorMapper.fromEnvelope(500, json));
              return;
          }
        }
      }
    } on DioException catch (e) {
      yield AiStreamFailed(ErrorMapper.fromDio(e));
      return;
    } on FormatException {
      yield const AiStreamFailed(Unknown());
      return;
    }
    // The connection closed before the answer was complete.
    yield const AiStreamFailed(
      Offline('The answer was cut off. Check your connection and try again.'),
    );
  }

  /// An HTTP error before the stream began: its body is still a stream, so
  /// read the §10 envelope out of it first.
  static Future<Failure> _streamFailure(DioException e) async {
    final body = e.response?.data;
    if (e.type != DioExceptionType.badResponse || body is! ResponseBody) {
      return ErrorMapper.fromDio(e);
    }
    Object? envelope;
    try {
      envelope = jsonDecode(await utf8.decodeStream(body.stream));
    } on Object {
      envelope = null;
    }
    return ErrorMapper.fromEnvelope(e.response?.statusCode ?? 0, envelope);
  }

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

  @override
  Future<Result<FoodGuideResponse>> foodGuide(FoodGuideRequest request) =>
      _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/nutrition/guide',
          data: request.toJson(),
          options: Options(receiveTimeout: const Duration(seconds: 45)),
        ),
        FoodGuideResponse.fromJson,
      );
}
