import 'package:flutter/material.dart';

import '../../../../core/config/env.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fitos_wordmark.dart';

/// Shown while the persisted session is being restored, and — if the build
/// was made without Firebase defines — as an honest error instead of a crash.
///
/// No spinner over 400ms of content (§6.6): this is a wordmark on paper. The
/// router leaves as soon as `AuthState` resolves, which is a local read.
class SplashGateScreen extends StatelessWidget {
  const SplashGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FitSpacing.screen),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const FitosWordmark(),
              if (Env.configurationProblem case final problem?) ...<Widget>[
                const SizedBox(height: FitSpacing.lg),
                const Divider(color: FitColors.rule, height: 1),
                const SizedBox(height: FitSpacing.afterRule),
                Text(
                  'This hosted build has an unusable server address.',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: FitSpacing.sm),
                Text(
                  '$problem. Rebuild with tool/hosted.ps1 and an https:// '
                  'address such as the Cloud Run URL.',
                  style: textTheme.bodyMedium,
                ),
              ] else if (!Env.firebaseConfigured) ...<Widget>[
                const SizedBox(height: FitSpacing.lg),
                const Divider(color: FitColors.rule, height: 1),
                const SizedBox(height: FitSpacing.afterRule),
                Text(
                  'Firebase is not configured for this build.',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: FitSpacing.sm),
                Text(
                  'Run with --dart-define for FIREBASE_API_KEY, FIREBASE_APP_ID, '
                  'FIREBASE_MESSAGING_SENDER_ID and FIREBASE_PROJECT_ID. '
                  'See apps/mobile/README.md.',
                  style: textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
