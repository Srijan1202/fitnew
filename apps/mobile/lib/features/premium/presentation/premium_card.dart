import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../domain/avatars.dart';
import 'premium_providers.dart';
import 'premium_sheet.dart';

/// Phase 19 (ADR-027): Profile → Premium — the status in one line, and the
/// way to ask for it (or to see what it unlocks).
class PremiumCard extends ConsumerWidget {
  const PremiumCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final s = ref.watch(premiumStatusProvider).value;
    final (line, action) = switch (s) {
      null => (
          'Premium unlocks FITOS AI, the weekly report, themes and more.',
          'See Premium'
        ),
      _ when s.premium => (
          s.source == 'admin'
              ? 'Premium, as an administrator.'
              : 'Premium is on.',
          'What Premium includes',
        ),
      _ when s.pending => ('Requested. Waiting for approval.', 'See Premium'),
      _ => (
          'Premium unlocks FITOS AI, the weekly report, themes and more.',
          'Request Premium'
        ),
    };
    return Container(
      key: const ValueKey('profile.premium'),
      width: double.infinity,
      padding: const EdgeInsets.all(FitSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: s?.premium == true ? kGold : FitColors.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.workspace_premium, color: kGold, size: 20),
              const SizedBox(width: FitSpacing.xs),
              Text('PREMIUM', style: textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            line,
            key: const ValueKey('profile.premium.line'),
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: FitSpacing.sm),
          OutlinedButton(
            key: const ValueKey('profile.premium.open'),
            style: OutlinedButton.styleFrom(
              shape: const RoundedRectangleBorder(),
              minimumSize: const Size.fromHeight(44),
              foregroundColor: kGoldDeep,
              side: const BorderSide(color: kGold),
            ),
            onPressed: () => showPremiumSheet(context),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
