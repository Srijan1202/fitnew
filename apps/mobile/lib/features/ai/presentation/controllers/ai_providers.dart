import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/ai_api.dart';
import '../../domain/entities/ai.dart';

final aiApiProvider =
    Provider<AiApi>((ref) => DioAiApi(ref.watch(dioProvider)));

/// Whether the server has a model set up, and what it never sees.
final aiStatusProvider = FutureProvider<AiStatus>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(aiApiProvider).status();
    return r.when(ok: (s) => s, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// One line of the conversation as the screen shows it.
class AiTurn {
  const AiTurn({
    required this.role,
    required this.text,
    this.actions = const [],
    this.failed = false,
  });

  final AiRole role;
  final String text;
  final List<AiAction> actions;

  /// A user turn the server did not answer (retry re-sends it).
  final bool failed;
}

class AiChatState {
  const AiChatState({
    this.turns = const [],
    this.sending = false,
    this.failure,
  });

  final List<AiTurn> turns;
  final bool sending;

  /// The last send's failure, shown under the exchange with Retry.
  final Failure? failure;

  AiChatState copyWith({
    List<AiTurn>? turns,
    bool? sending,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      AiChatState(
        turns: turns ?? this.turns,
        sending: sending ?? this.sending,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

/// The conversation on this phone for this sign-in. Stateless server: the
/// recent exchange travels with every message; nothing is stored.
class AiChatController extends Notifier<AiChatState> {
  @override
  AiChatState build() {
    // A new sign-in starts a new conversation.
    ref.watch(sessionUserIdProvider);
    return const AiChatState();
  }

  Future<void> send(String message) async {
    final text = message.trim();
    if (text.isEmpty || state.sending) return;
    final history = [
      for (final t in state.turns)
        if (!t.failed) AiChatMessage(role: t.role, content: t.text),
    ];
    state = state.copyWith(
      turns: [...state.turns, AiTurn(role: AiRole.user, text: text)],
      sending: true,
      clearFailure: true,
    );
    final r = await ref.read(aiApiProvider).chat(
          AiChatRequest(message: text, history: history),
        );
    r.when(
      ok: (answer) => state = state.copyWith(
        turns: [
          ...state.turns,
          AiTurn(
            role: AiRole.assistant,
            text: answer.text,
            actions: answer.actions,
          ),
        ],
        sending: false,
      ),
      err: (f) {
        // Mark the last user turn as unanswered so Retry can resend it.
        final turns = [...state.turns];
        final last = turns.removeLast();
        turns.add(AiTurn(role: last.role, text: last.text, failed: true));
        state = state.copyWith(turns: turns, sending: false, failure: f);
      },
    );
  }

  /// Re-send the last unanswered message.
  Future<void> retry() async {
    final failed = state.turns.lastWhere(
      (t) => t.failed,
      orElse: () => const AiTurn(role: AiRole.user, text: ''),
    );
    if (failed.text.isEmpty) return;
    state = state.copyWith(
      turns: state.turns.where((t) => !t.failed).toList(),
      clearFailure: true,
    );
    await send(failed.text);
  }

  void clear() => state = const AiChatState();
}

final aiChatProvider =
    NotifierProvider<AiChatController, AiChatState>(AiChatController.new);
