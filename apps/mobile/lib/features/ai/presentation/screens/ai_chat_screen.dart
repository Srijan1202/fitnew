import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../training/presentation/controllers/program_controller.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../domain/entities/ai.dart';
import '../controllers/ai_providers.dart';
import '../../../premium/presentation/premium_providers.dart';
import '../../../premium/presentation/premium_sheet.dart';
import '../../../privacy/presentation/privacy_providers.dart';
import '../../../../shared/widgets/fit_glass.dart';

/// Phase 6.6 — FITOS AI (Part 7). The conversation as a running editorial
/// column: "YOU" and "FITOS AI" eyebrows, hairlines between turns, the
/// assistant's actions as outlined buttons, starter prompts on the empty
/// screen, a thinking line while the server answers, an error line with
/// Retry. No bubbles, no avatars. When the server has no model, says so.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  /// Only prompts the assistant can answer (the food log is not shared with it).
  static const starterPrompts = <String>[
    'What should I do today?',
    "Explain today's workout",
    'How am I progressing?',
    'Why is my volume high?',
    'What did I do last workout?',
    'Build me a new program',
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
    // Phase 19: FITOS AI is premium; Phase 17: and its own consent.
    if (!await ensurePremium(context, ref, feature: 'FITOS AI') || !mounted) {
      return;
    }
    if (!await ensureAiConsent(context, ref) || !mounted) return;
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
      case AiActionType.applyProgram:
        await _applyProgram(a);
    }
  }

  /// Gate 5: the one consequential action. The assistant only proposed;
  /// the programme changes here, after the user confirms, through the same
  /// request the ordinary generate / template screens send.
  Future<void> _applyProgram(AiAction a) async {
    final request = a.programRequest;
    if (request == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('ai.applyProgram.confirm'),
        title: const Text('Replace your programme?'),
        content: const Text(
          'FITOS will build this programme from your profile and make it your active plan. Your current programme is kept, but no longer active.',
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey('ai.applyProgram.cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep current'),
          ),
          FilledButton(
            key: const ValueKey('ai.applyProgram.ok'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Use this programme'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final controller = ref.read(programControllerProvider.notifier);
    final template = request.template;
    final failure = template != null
        ? await controller.applyTemplate(
            template,
            preferredSessionMinutes: request.preferredSessionMinutes,
            emphasis: request.emphasis,
          )
        : await controller.generate(
            daysPerWeek: request.daysPerWeek,
            preferredSessionMinutes: request.preferredSessionMinutes,
            emphasis: request.emphasis,
          );
    if (!mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const ValueKey('ai.applyProgram.failed'),
          content: Text(failure.message),
        ),
      );
      return;
    }
    // The plan and today's prescription changed on the server.
    ref
      ..invalidate(todayProvider)
      ..invalidate(volumeProvider);
    context.go(Routes.plan);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(aiStatusProvider);
    final chat = ref.watch(aiChatProvider);
    // Beta 3.8: keep the answer in view while it is written.
    ref.listen(aiChatProvider.select((c) => c.partial), (_, next) {
      if (next != null) _toBottom();
    });
    final s = status.value;
    // Phase 19 (ADR-027): a free user sees what premium is, and the request.
    final locked = ref.watch(isPremiumProvider) == false;
    final configured = !locked && (s == null || (s.enabled && s.configured));

    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: FitBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              // The tabs' header (owner 2026-10-30), in place of a bar that
              // held only the F mark.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FitSpacing.screen,
                  FitSpacing.lg,
                  FitSpacing.sm,
                  FitSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('AI', style: t.labelSmall),
                          const SizedBox(height: FitSpacing.xs),
                          Text(
                            'FITOS AI',
                            key: const ValueKey('ai.title'),
                            style: t.displaySmall,
                          ),
                        ],
                      ),
                    ),
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
              ),
              Expanded(
                child: locked
                    ? const SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          FitSpacing.screen,
                          FitSpacing.md,
                          FitSpacing.screen,
                          FitSpacing.xl,
                        ),
                        child: PremiumPitch(
                          key: ValueKey('ai.premium'),
                          feature: 'FITOS AI',
                        ),
                      )
                    : status.when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) => _Unavailable(
                          message: (e is Failure ? e : const Unknown()).message,
                          onRetry: () => ref.invalidate(aiStatusProvider),
                        ),
                        data: (s) => !s.enabled
                            ? const _NotConfigured(switchedOff: true)
                            : !s.configured
                                ? const _NotConfigured()
                                : chat.turns.isEmpty
                                    ? _Empty(onPrompt: _send)
                                    : _Conversation(
                                        controller: _scroll,
                                        state: chat,
                                        onAction: _act,
                                        onRetry: () => ref
                                            .read(aiChatProvider.notifier)
                                            .retry(),
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
    if (fitGlass) {
      // ADR-029: a floating rounded field above the floating bar.
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, FitSpacing.sm, 12, 84),
        child: DecoratedBox(
          decoration: FitBlock.decoration(radius: const Radius.circular(26)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(FitSpacing.md, 4, 6, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(child: _field(textTheme)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: IconButton.filled(
                    key: const ValueKey('ai.send'),
                    onPressed: enabled ? () => onSend() : null,
                    icon: const Icon(Icons.arrow_upward),
                    style: IconButton.styleFrom(
                      backgroundColor: FitColors.accent,
                      foregroundColor: FitColors.onAccent,
                      disabledBackgroundColor:
                          FitColors.ink.withValues(alpha: 0.12),
                    ),
                    tooltip: 'Send',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      // Sits above the floating bar.
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.sm,
        84,
      ),
      decoration: BoxDecoration(
        color: FitColors.paper,
        border: Border(top: BorderSide(color: FitColors.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(child: _field(textTheme)),
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

extension on _Composer {
  Widget _field(TextTheme textTheme) => TextField(
        key: const ValueKey('ai.input'),
        controller: controller,
        enabled: enabled,
        minLines: 1,
        maxLines: 4,
        maxLength: 2000,
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => onSend(),
        style: textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Ask FITOS AI…',
          counterText: '',
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              fitGlass ? const EdgeInsets.symmetric(vertical: 12) : null,
        ),
      );
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
        FitSpacing.sm,
        FitSpacing.screen,
        FitSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The tab's header names FITOS AI above this.
          Text('Ask about your training.', style: textTheme.headlineSmall),
          const SizedBox(height: FitSpacing.sm),
          Text(
            'It answers from your own FITOS data — your plan, your logged sessions, your progression, your targets. It cannot see food you have not logged, or the health data that stays on your phone.',
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.lg),
          Text('TRY', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          if (fitGlass)
            FitGroup(
              children: <Widget>[
                for (final (i, p) in AiChatScreen.starterPrompts.indexed)
                  FitRow(
                    key: ValueKey('ai.prompt.$i'),
                    icon: Icons.auto_awesome,
                    title: p,
                    onTap: () => onPrompt(p),
                    trailing: Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: FitColors.ink60,
                    ),
                  ),
              ],
            )
          else ...<Widget>[
            for (final p in AiChatScreen.starterPrompts) ...<Widget>[
              Divider(color: FitColors.rule, height: 1),
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
                      Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: FitColors.ink60,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Divider(color: FitColors.rule, height: 1),
          ],
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
          if (i > 0) const FitRule(),
          _Bubble(
            user: t.role == AiRole.user,
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
        if (state.sending && state.partial != null) ...<Widget>[
          // Beta 3.8: FITOS AI's answer as it is written.
          const FitRule(),
          _Bubble(
            user: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('FITOS AI', style: textTheme.labelSmall),
                const SizedBox(height: FitSpacing.xs),
                Text(
                  state.partial!,
                  key: const ValueKey('ai.partial'),
                  style: textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ] else if (state.sending) ...<Widget>[
          const FitRule(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
            child: Row(
              children: <Widget>[
                SizedBox(
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
          const FitRule(),
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

/// ADR-029: on glass, a turn is a bubble — yours on the right in the
/// accent's tint, FITOS AI's on the left in a block. On Paper, the turn sits
/// between hairlines as before.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.user, required this.child});

  final bool user;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!fitGlass) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
        child: child,
      );
    }
    const radius = Radius.circular(20);
    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: user
          ? BoxDecoration(
              color: FitPalette.current.glow.withValues(alpha: 0.16),
              border: Border.all(
                color: FitPalette.current.glow.withValues(alpha: 0.35),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: radius,
                topRight: radius,
                bottomLeft: radius,
                bottomRight: Radius.circular(6),
              ),
            )
          : FitBlock.decoration().copyWith(
              borderRadius: const BorderRadius.only(
                topLeft: radius,
                topRight: radius,
                bottomLeft: Radius.circular(6),
                bottomRight: radius,
              ),
            ),
      child: child,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            user ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: FractionallySizedBox(
              widthFactor: user ? 0.85 : 0.94,
              alignment: user ? Alignment.centerRight : Alignment.centerLeft,
              child: bubble,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured({this.switchedOff = false});

  /// Phase 14: the server's kill switch is off (AI_ENABLED=false).
  final bool switchedOff;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      key: ValueKey(switchedOff ? 'ai.switchedOff' : 'ai.notConfigured'),
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('FITOS AI', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Text(
            switchedOff
                ? 'Switched off for now.'
                : 'Not set up on this server yet.',
            style: textTheme.displaySmall,
          ),
          const SizedBox(height: FitSpacing.sm),
          Text(
            switchedOff
                ? 'FITOS AI has been turned off on the server for the moment. Everything else in FITOS works as usual.'
                : 'The assistant runs on the FITOS server. This build\'s server has no model configured, so there is nothing to ask yet. Everything else in FITOS works as usual.',
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
