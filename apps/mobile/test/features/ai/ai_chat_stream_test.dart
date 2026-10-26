import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/features/ai/data/ai_api.dart';
import 'package:fitos/features/ai/domain/entities/ai.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 3.8: DioAiApi.chatStream over Dio's real response plumbing — the
/// server's events split anywhere, an error before the stream began (its
/// envelope read out of the stream), an error event, a server from before
/// 3.8 (404: asked the old way) and a connection cut mid-answer.
class _Server implements HttpClientAdapter {
  /// Path → (status, the body in the pieces it arrives in, content type).
  final answers = <String, (int, List<String>, String)>{};
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final (status, pieces, type) = answers[options.path]!;
    return ResponseBody(
      Stream.fromIterable([
        for (final p in pieces) Uint8List.fromList(utf8.encode(p)),
      ]),
      status,
      headers: {
        Headers.contentTypeHeader: [type],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Server server;
  late DioAiApi api;
  const request = AiChatRequest(message: 'What now?');
  const sse = 'text/event-stream';
  const done = {
    'text': 'Pull day: 4 movements.',
    'actions': <Object>[],
    'toolsUsed': ['get_today'],
    'model': 'fake-1',
  };
  String event(String name, Object data) =>
      'event: $name\ndata: ${jsonEncode(data)}\n\n';

  setUp(() {
    server = _Server();
    api = DioAiApi(
      Dio(BaseOptions(baseUrl: 'https://api.example'))
        ..httpClientAdapter = server,
    );
  });

  test('events split anywhere: text so far, a tool round, the final answer',
      () async {
    final body = event('text', {'type': 'text', 'text': 'Pull day:'}) +
        event('tool', {'type': 'tool'}) +
        event('text', {'type': 'text', 'text': 'Pull day: 4 move'}) +
        event('done', done);
    server.answers['/v1/ai/chat/stream'] = (
      200,
      [body.substring(0, 9), body.substring(9, 50), body.substring(50)],
      sse
    );
    final events = await api.chatStream(request).toList();
    expect(events, hasLength(4));
    expect((events[0] as AiStreamText).text, 'Pull day:');
    expect(events[1], isA<AiStreamTool>());
    expect((events[2] as AiStreamText).text, 'Pull day: 4 move');
    expect((events[3] as AiStreamDone).answer.text, 'Pull day: 4 movements.');
    expect(server.paths, ['/v1/ai/chat/stream']);
  });

  test(
      'a refusal before the stream began reads the envelope; an error event too',
      () async {
    server.answers['/v1/ai/chat/stream'] = (
      429,
      [
        jsonEncode({
          'error': {
            'code': 'RATE_LIMITED',
            'message': 'You have used this 20 times in the last hour.',
            'requestId': 'r1',
          },
        }),
      ],
      'application/json',
    );
    final refused = await api.chatStream(request).single;
    expect(
      (refused as AiStreamFailed).failure,
      isA<RateLimited>().having(
        (f) => f.message,
        'message',
        'You have used this 20 times in the last hour.',
      ),
    );

    server.answers['/v1/ai/chat/stream'] = (
      200,
      [
        event('error', {
          'error': {
            'code': 'UPSTREAM_UNAVAILABLE',
            'message': 'FITOS AI is busy right now. Try again in a minute.',
            'requestId': 'r2',
          },
        }),
      ],
      sse,
    );
    final failed = await api.chatStream(request).single;
    expect((failed as AiStreamFailed).failure, isA<ServiceUnavailable>());
  });

  test('a server from before beta 3.8 (404) is asked the old way', () async {
    server.answers['/v1/ai/chat/stream'] = (
      404,
      [
        jsonEncode({
          'error': {
            'code': 'NOT_FOUND',
            'message': 'No route.',
            'requestId': 'r',
          },
        }),
      ],
      'application/json',
    );
    server.answers['/v1/ai/chat'] =
        (200, [jsonEncode(done)], 'application/json');
    final only = await api.chatStream(request).single;
    expect((only as AiStreamDone).answer.toolsUsed, ['get_today']);
    expect(server.paths, ['/v1/ai/chat/stream', '/v1/ai/chat']);
  });

  test('cut off before the answer was done: a failure, never a half answer',
      () async {
    server.answers['/v1/ai/chat/stream'] = (
      200,
      [
        event('text', {'type': 'text', 'text': 'Pull day: 4'}),
      ],
      sse
    );
    final events = await api.chatStream(request).toList();
    expect(events.first, isA<AiStreamText>());
    expect((events.last as AiStreamFailed).failure, isA<Offline>());
  });
}
