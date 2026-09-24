import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../domain/today.dart';
import 'today_words.dart';

/// What the user chose in the "why" sheet.
enum WhyChoice { primary, dismiss }

/// A server TODAY action's "why": the headline, the server's detail, the
/// facts from its structured reason, and where the decision came from —
/// with the same two choices as the card. Opening it is the `opened` event
/// (the caller records it); nothing is recorded here.
Future<WhyChoice?> showTodayWhySheet(
  BuildContext context, {
  required TodayAction action,
  required bool messConfigured,
  required bool canDismiss,
  required bool cached,
}) {
  final textTheme = Theme.of(context).textTheme;
  final kind = action.kind!;
  final facts = TodayWords.facts(action.reason);
  return showModalBottomSheet<WhyChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('today.why'),
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          0,
          FitSpacing.screen,
          FitSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              TodayWords.eyebrow(kind),
              style: textTheme.labelSmall
                  ?.copyWith(color: TodayWords.eyebrowColor(kind)),
            ),
            const SizedBox(height: FitSpacing.xs),
            Text(
              action.headline,
              key: const ValueKey('today.why.headline'),
              style: textTheme.displaySmall,
            ),
            const SizedBox(height: FitSpacing.sm),
            Text(
              action.detail,
              key: const ValueKey('today.why.detail'),
              style: textTheme.bodyLarge,
            ),
            if (facts.isNotEmpty) ...<Widget>[
              const SizedBox(height: FitSpacing.md),
              for (final (label, value) in facts)
                Padding(
                  padding: const EdgeInsets.only(bottom: FitSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: Text(
                          label,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: FitColors.ink60),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          value,
                          key: ValueKey('today.why.fact.$label'),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: FitSpacing.md),
            const Divider(color: FitColors.rule, height: 1),
            const SizedBox(height: FitSpacing.sm),
            Text(
              'Why this was suggested: ${action.basis.label.toLowerCase()}.'
              '${cached ? ' Shown from the last plan while you are offline.' : ''}',
              key: const ValueKey('today.why.basis'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
            const SizedBox(height: FitSpacing.md),
            FilledButton(
              key: const ValueKey('today.why.primary'),
              onPressed: () => Navigator.of(context).pop(WhyChoice.primary),
              child: Text(
                TodayWords.primary(action, messConfigured: messConfigured),
              ),
            ),
            if (canDismiss)
              TextButton(
                key: const ValueKey('today.why.dismiss'),
                onPressed: () => Navigator.of(context).pop(WhyChoice.dismiss),
                child: const Text('Not today'),
              ),
          ],
        ),
      ),
    ),
  );
}
