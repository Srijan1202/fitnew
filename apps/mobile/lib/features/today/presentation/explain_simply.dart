import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/theme/tokens.dart';
import '../../ai/domain/entities/ai_draft.dart';
import '../../ai/presentation/controllers/ai_providers.dart';
import '../../privacy/presentation/privacy_providers.dart';

/// Phase 14 (ADR-020 D5): "Explain simply" under a TODAY action's reason.
/// The server rewords the engine's reason; a rewording that brings in any
/// number the engine did not give is thrown away and the engine's own words
/// come back instead, labelled so (§19.2). Offered only while FITOS AI is
/// on and set up, and not for a plan shown from the offline cache.
class ExplainSimply extends ConsumerStatefulWidget {
  const ExplainSimply({required this.actionId, super.key});

  final String actionId;

  @override
  ConsumerState<ExplainSimply> createState() => _ExplainSimplyState();
}

class _ExplainSimplyState extends ConsumerState<ExplainSimply> {
  bool _loading = false;
  ExplainResponse? _answer;
  Failure? _failure;

  Future<void> _ask() async {
    // Phase 17: FITOS AI is its own consent (asked once, before first use).
    if (!await ensureAiConsent(context, ref) || !mounted) return;
    setState(() {
      _loading = true;
      _failure = null;
    });
    final r = await ref.read(aiApiProvider).explain(widget.actionId);
    if (!mounted) return;
    r.when(
      ok: (a) => setState(() {
        _answer = a;
        _loading = false;
      }),
      err: (f) => setState(() {
        _failure = f;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(aiAvailableProvider)) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final answer = _answer;
    final failure = _failure;
    if (answer != null) {
      final ai = answer.source == ExplainSource.ai;
      return Container(
        key: const ValueKey('today.why.simple'),
        margin: const EdgeInsets.only(top: FitSpacing.md),
        padding: const EdgeInsets.all(FitSpacing.md),
        decoration: BoxDecoration(border: Border.all(color: FitColors.rule)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              ai ? 'IN PLAIN WORDS · FITOS AI' : "FITOS'S OWN WORDS",
              key: const ValueKey('today.why.simple.label'),
              style: textTheme.labelSmall,
            ),
            const SizedBox(height: FitSpacing.xs),
            Text(
              answer.text,
              key: const ValueKey('today.why.simple.text'),
              style: textTheme.bodyLarge,
            ),
            if (!ai) ...<Widget>[
              const SizedBox(height: FitSpacing.xs),
              Text(
                'The simpler version was not used: it '
                '${answer.discarded == 'new-number' ? 'added a number FITOS did not give' : 'did not come out right'}.',
                key: const ValueKey('today.why.simple.note'),
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          OutlinedButton.icon(
            key: const ValueKey('today.why.explain'),
            style: OutlinedButton.styleFrom(
              shape: const RoundedRectangleBorder(),
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _loading ? null : _ask,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(_loading ? 'Explaining…' : 'Explain simply'),
          ),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.only(top: FitSpacing.xs),
              child: Text(
                aiFailureText(failure),
                key: const ValueKey('today.why.explain.error'),
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
            ),
        ],
      ),
    );
  }
}
