import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../controllers/workout_providers.dart';

/// "3 to sync" in amber while the queue drains, "2 not synced · Retry" in
/// oxide when entries gave up. Nothing when everything is on the server —
/// the normal case should look like nothing.
class SyncPill extends ConsumerWidget {
  const SyncPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final status = ref.watch(syncStatusProvider).value;
    if (status == null || status.clean) return const SizedBox.shrink();
    final repo = ref.read(workoutRepositoryProvider);
    if (status.parked > 0) {
      return TextButton(
        key: const ValueKey('sync.retry'),
        onPressed: repo.retryParked,
        child: Text(
          '${status.parked} not synced · Retry',
          style: textTheme.labelSmall?.copyWith(color: FitColors.oxide),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FitSpacing.sm),
      child: Center(
        child: Text(
          '${status.pending} to sync',
          key: const ValueKey('sync.pending'),
          style: textTheme.labelSmall?.copyWith(color: FitColors.amber),
        ),
      ),
    );
  }
}
