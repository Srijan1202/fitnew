import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/fit_glass.dart';
import '../domain/avatars.dart';
import 'premium_providers.dart';
import 'premium_sheet.dart';

/// Phase 19 (ADR-027): Profile → Premium — the status in one line, and the
/// way to ask for it (or to see what it unlocks). ADR-029: a gold list row.
class PremiumCard extends ConsumerWidget {
  const PremiumCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(premiumStatusProvider).value;
    final line = switch (s) {
      null => 'See what it unlocks',
      _ when s.premium => s.source == 'admin' ? 'Admin' : 'Active',
      _ when s.pending => 'Requested',
      _ => 'Request',
    };
    return FitRow(
      key: const ValueKey('profile.premium.open'),
      icon: Icons.workspace_premium,
      tint: kGold,
      title: 'Premium',
      value: line,
      valueKey: const ValueKey('profile.premium.line'),
      onTap: () => showPremiumSheet(context),
    );
  }
}
