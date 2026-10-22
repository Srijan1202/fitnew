import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../data/premium_api.dart';
import '../domain/premium.dart';
import 'premium_sheet.dart';

final premiumApiProvider =
    Provider<PremiumApi>((ref) => DioPremiumApi(ref.watch(dioProvider)));

/// Phase 19 (ADR-027): am I premium, and where is my request. Refetched after
/// a request; the server decides everything.
final premiumStatusProvider = FutureProvider<PremiumStatus>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(premiumApiProvider).status();
    return r.when(ok: (s) => s, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// True or false once known; null while loading or unreachable (then the
/// server still enforces every premium rule).
final isPremiumProvider = Provider<bool?>(
  (ref) => ref.watch(premiumStatusProvider).value?.premium,
);

/// Before a premium feature: true when premium (or not yet known: the
/// server decides); otherwise the premium sheet, with what it unlocks and the
/// request, and false.
Future<bool> ensurePremium(
  BuildContext context,
  WidgetRef ref, {
  required String feature,
}) async {
  final PremiumStatus status;
  try {
    status = await ref.read(premiumStatusProvider.future);
  } on Object {
    return true;
  }
  if (status.premium) return true;
  if (!context.mounted) return false;
  await showPremiumSheet(context, feature: feature);
  return false;
}
