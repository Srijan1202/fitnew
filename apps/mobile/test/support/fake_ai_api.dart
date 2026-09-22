import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/ai/data/ai_api.dart';
import 'package:fitos/features/ai/domain/entities/ai.dart';

/// A scripted FITOS AI server: status as set; every chat answers from
/// `nextAnswer` (or fails with `nextFailure`) and records the request.
class FakeAiApi implements AiApi {
  AiStatus status_ = const AiStatus(
    configured: true,
    provider: 'fake',
    model: 'fake-1',
    excludes: ['health-connect', 'food-log'],
  );
  Failure? statusFailure;
  AiChatResponse nextAnswer = const AiChatResponse(
    text: 'Pull is ready: 4 movements, about 45 minutes.',
    actions: [
      AiAction(type: AiActionType.openWorkout, label: "Open today's workout"),
    ],
    toolsUsed: ['get_today'],
    model: 'fake-1',
  );
  Failure? nextFailure;
  final requests = <AiChatRequest>[];
  final calls = <String>[];

  @override
  Future<Result<AiStatus>> status() async {
    calls.add('status');
    final f = statusFailure;
    return f == null ? Ok(status_) : Err(f);
  }

  @override
  Future<Result<AiChatResponse>> chat(AiChatRequest request) async {
    calls.add('chat');
    requests.add(request);
    final f = nextFailure;
    if (f != null) return Err(f);
    return Ok(nextAnswer);
  }
}
