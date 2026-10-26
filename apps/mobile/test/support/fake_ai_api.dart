import 'dart:async';

import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/ai/data/ai_api.dart';
import 'package:fitos/features/ai/domain/entities/ai.dart';
import 'package:fitos/features/ai/domain/entities/ai_draft.dart';
import 'package:fitos/features/ai/domain/entities/food_guide.dart';

/// A scripted FITOS AI server: status as set; every chat answers from
/// `nextAnswer` (or fails with `nextFailure`) and records the request.
class FakeAiApi implements AiApi {
  FakeAiApi();

  /// AI switched off on the server (the default for widget tests that do
  /// not exercise FITOS AI: no AI entry point is offered).
  FakeAiApi.off() {
    status_ = status_.copyWith(enabled: false);
  }

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

  /// Phase 14: the next parse answer (or failure), and every text sent.
  ParseFoodResponse? nextDraft;
  Failure? parseFailure;
  final parsed = <String>[];

  /// Phase 14: the next explanation (or failure), and every action id sent.
  ExplainResponse nextExplain = const ExplainResponse(
    text: 'Weigh in today so your trend stays honest.',
    source: ExplainSource.ai,
  );
  Failure? explainFailure;
  final explained = <String>[];
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

  /// Beta 3.8: the answer so far, shown before the answer is done (none: the
  /// answer arrives whole); [streamGate], when set, holds the stream after
  /// those pieces until it completes.
  List<String> streamTexts = const [];
  Completer<void>? streamGate;

  /// Counted like [chat]: a send is a chat whichever way it is answered.
  @override
  Stream<AiStreamEvent> chatStream(AiChatRequest request) async* {
    calls.add('chat');
    requests.add(request);
    for (final t in streamTexts) {
      yield AiStreamText(t);
    }
    final gate = streamGate;
    if (gate != null) await gate.future;
    final f = nextFailure;
    yield f != null ? AiStreamFailed(f) : AiStreamDone(nextAnswer);
  }

  @override
  Future<Result<ParseFoodResponse>> parseFood(String text) async {
    calls.add('parse');
    parsed.add(text);
    final f = parseFailure;
    if (f != null) return Err(f);
    final d = nextDraft;
    return d == null ? const Err(Unknown()) : Ok(d);
  }

  @override
  Future<Result<ExplainResponse>> explain(String actionId) async {
    calls.add('explain');
    explained.add(actionId);
    final f = explainFailure;
    return f == null ? Ok(nextExplain) : Err(f);
  }

  /// Beta 3.6: the next food guide answer (or failure), and every request.
  FoodGuideResponse? nextGuide;
  Failure? guideFailure;
  final guided = <FoodGuideRequest>[];

  @override
  Future<Result<FoodGuideResponse>> foodGuide(FoodGuideRequest request) async {
    calls.add('guide');
    guided.add(request);
    final f = guideFailure;
    if (f != null) return Err(f);
    final g = nextGuide;
    return g == null ? const Err(Unknown()) : Ok(g);
  }
}
