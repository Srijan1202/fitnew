import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// Phase 17 (§23.1, ADR-023 D1): FITOS AI is its own purpose. Says plainly
/// what goes where before the first use; true when allowed.
Future<bool?> showAiConsentSheet(BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  return showModalBottomSheet<bool>(
    // Above the floating tab bar (beta 4.8, owner: Save hid behind it).
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('aiConsent.sheet'),
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
            Text('FITOS AI', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            Text('Allow FITOS AI?', style: textTheme.displaySmall),
            const SizedBox(height: FitSpacing.sm),
            Text(
              "FITOS AI answers with Google's Gemini. To do that, FITOS sends "
              'Google what you ask:',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: FitSpacing.sm),
            for (final line in const [
              'Chat: your message and the FITOS data it needs — your profile, '
                  'goal, programme, today and recent workouts.',
              'Describe your meal: only the words you type.',
              'Explain simply: that one suggestion and its numbers.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: FitSpacing.xs),
                child: Text('·  $line', style: textTheme.bodyMedium),
              ),
            const SizedBox(height: FitSpacing.sm),
            Text(
              'Health Connect data never leaves your phone. During the alpha, '
              "FITOS uses Google's free tier, where Google may use what is sent "
              'to improve its products. You can turn this off any time in '
              'Profile › Privacy & data.',
              style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
            const SizedBox(height: FitSpacing.md),
            FilledButton(
              key: const ValueKey('aiConsent.allow'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow FITOS AI'),
            ),
            TextButton(
              key: const ValueKey('aiConsent.notNow'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    ),
  );
}
