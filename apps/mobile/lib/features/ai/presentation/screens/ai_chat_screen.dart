import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fitos_wordmark.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../domain/entities/ai.dart';
import '../controllers/ai_providers.dart';

/// Phase 6.6 — FITOS AI (Part 7). The conversation as a running editorial
/// column: "YOU" and "FITOS AI" eyebrows, hairlines between turns, the
/// assistant's actions as outlined buttons, starter prompts on the empty
/// screen, a thinking line while the server answers, an error line with
/// Retry. No bubbles, no avatars. When the server has no model, says so.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  /// Only prompts the current build can answer (no Phase 8 food logging).
  static const starterPrompts = <String>[
    'What should I do today?',
    "Explain today's workout",
    'How am I progressing?',
    'Why is my volume high?',
    'What did I do last workout?',
    'What are my calorie and protein targets?',
  ];

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final message = (text ?? _input.text).trim();
    if (message.isEmpty) return;
    _input.clear();
    await ref.read(aiChatProvider.notifier).send(message);
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _act(AiAction a) async {
    switch (a.type) {
      case AiActionType.openWorkout:
        final active =
            await ref.read(workoutRepositoryProvider).activeSession();
        if (!mounted) return;
        if (active != null) {
          await context.push(Routes.session(active.clientSessionId));
        } else {
          context.go(Routes.plan);
        }
      case AiActionType.openPlan:
        context.go(Routes.plan);
      case AiActionType.openVolume:
        await context.push(Routes.volume);
      case AiActionType.openProgression:
      case AiActionType.openExercise:
        if (a.exerciseId != null) {
          await context.push(Routes.exerciseDetail(a.exerciseId!));
        }
      case AiActionType.openProfile:
        await context.push(Routes.profile);
      case AiActionType.openNutrition:
        context.go(Routes.nutrition);
      case AiActionType.openHistory:
        await context.push(Routes.history);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(aiStatusProvider);
    final chat = ref.watch(aiChatProvider);
    final configured = status.value?.configured ?? true;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: FitSpacing.screen,
        title: const FitosWordmark(size: 20, withName: false),
        actions: <Widget>[
          if (chat.turns.isNotEmpty)
            TextButton(
              key: const ValueKey('ai.clear'),
              onPressed: chat.sending
                  ? null
                  : () => ref.read(aiChatProvider.notifier).clear(),
              child: const Text('New chat'),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: status.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => _Unavailable(
                  message: (e is Failure ? e : const Unknown()).message,
                  onRetry: () => ref.invalidate(aiStatusProvider),
                ),
                data: (s) => !s.configured
                    ? const _NotConfigured()
                    : chat.turns.isEmpty
                        ? _Empty(onPrompt: _send)
                        : _Conversation(
                            controller: _scroll,
                            state: chat,
                            onAction: _act,
                            onRetry: () =>
                                ref.read(aiChatProvider.notifier).retry(),
                          ),
              ),
            ),
            _Composer(
              controller: _input,
              enabled: configured && !chat.sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final Future<void> Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      // Sits above the floating bar.
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.sm,
        84,
      ),
      decoration: const BoxDecoration(
        color: FitColors.paper,
        border: Border(top: BorderSide(color: FitColors.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              key: const ValueKey('ai.input'),
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: textTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Ask FITOS AI…',
                counterText: '',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('ai.send'),
            onPressed: enabled ? () => onSend() : null,
            icon: const Icon(Icons.arrow_upward),
            color: FitColors.ink,
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onPrompt});

  final Future<void> Function([String?]) onPrompt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Small, static content: a plain scroll view keeps every prompt in the
    // tree (a lazy list would drop the ones below the fold).
    return SingleChildScrollView(
      key: const ValueKey('ai.empty'),
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.lg,
        FitSpacing.screen,
        FitSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('FITOS AI', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Text('Ask about your training.', style: textTheme.displayMedium),
          const SizedBox(height: FitSpacing.sm),
          Text(
            'It answers from your own FITOS data — your plan, your logged sessions, your progression, your targets. It cannot see food you have not logged, or the health data that stays on your phone.',
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.lg),
          Text('TRY', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          for (final p in AiChatScreen.starterPrompts) ...<Widget>[
            const Divider(color: FitColors.rule, height: 1),
            InkWell(
              key: ValueKey(
                'ai.prompt.${AiChatScreen.starterPrompts.indexOf(p)}',
              ),
              onTap: () => onPrompt(p),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(p, style: textTheme.titleMedium)),
                    const Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: FitColors.ink60,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Divider(color: FitColors.rule, height: 1),
        ],
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.controller,
    required this.state,
    required this.onAction,
    required this.onRetry,
  });

  final ScrollController controller;
  final AiChatState state;
  final ValueChanged<AiAction> onAction;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      key: const ValueKey('ai.conversation'),
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.md,
        FitSpacing.screen,
        FitSpacing.lg,
      ),
      children: <Widget>[
        for (final (i, t) in state.turns.indexed) ...<Widget>[
          if (i > 0) const Divider(color: FitColors.rule, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  t.role == AiRole.user ? 'YOU' : 'FITOS AI',
                  style: textTheme.labelSmall?.copyWith(
                    color:
                        t.role == AiRole.user ? FitColors.ink60 : FitColors.ink,
                  ),
                ),
                const SizedBox(height: FitSpacing.xs),
                SelectableText(
                  t.text,
                  key: ValueKey('ai.turn.$i'),
                  style: t.role == AiRole.user
                      ? textTheme.bodyLarge?.copyWith(color: FitColors.ink60)
                      : textTheme.bodyLarge,
                ),
                if (t.actions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: FitSpacing.sm),
                  Wrap(
                    spacing: FitSpacing.sm,
                    runSpacing: FitSpacing.sm,
                    children: <Widget>[
                      for (final a in t.actions)
                        OutlinedButton(
                          key: ValueKey('ai.action.${a.type.wire}'),
                          onPressed: () => onAction(a),
                          child: Text(a.label),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        if (state.sending) ...<Widget>[
          const Divider(color: FitColors.rule, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
            child: Row(
              children: <Widget>[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FitColors.ink60,
                  ),
                ),
                const SizedBox(width: FitSpacing.sm),
                Text(
                  'Thinking…',
                  key: const ValueKey('ai.thinking'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
              ],
            ),
          ),
        ],
        if (state.failure != null) ...<Widget>[
          const Divider(color: FitColors.rule, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  state.failure!.message,
                  key: const ValueKey('ai.error'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
                ),
                const SizedBox(height: FitSpacing.sm),
                OutlinedButton(
                  key: const ValueKey('ai.retry'),
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('ai.notConfigured'),
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('FITOS AI', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Text('Not set up on this server yet.', style: textTheme.displaySmall),
          const SizedBox(height: FitSpacing.sm),
          Text(
            'The assistant runs on the FITOS server. This build\'s server has no model configured, so there is nothing to ask yet. Everything else in FITOS works as usual.',
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: const ValueKey('ai.unavailable'),
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('FITOS AI', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Text('Could not reach FITOS AI.', style: textTheme.displaySmall),
          const SizedBox(height: FitSpacing.sm),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.md),
          OutlinedButton(
            key: const ValueKey('ai.status.retry'),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
