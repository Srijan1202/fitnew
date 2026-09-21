import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/hairline_section.dart';
import '../../domain/entities/health.dart';
import '../controllers/health_providers.dart';

/// Phase 6.5 — Health Connect connection (Part G). Says why FITOS wants
/// the data, shows Connected / Not connected and the grant per category
/// (Activity, Recovery, Body), and offers Connect / Manage permissions /
/// Refresh. Unsupported devices get an honest explanation. The step goal
/// (owner D4) lives here too.
class HealthDataScreen extends ConsumerWidget {
  const HealthDataScreen({super.key});

  static String grantLabel(CategoryGrant g) => switch (g) {
        CategoryGrant.all => 'Allowed',
        CategoryGrant.partial => 'Partly allowed',
        CategoryGrant.none => 'Not allowed',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final conn = ref.watch(healthConnectionProvider);
    final snapshot = ref.watch(healthSnapshotProvider).value;
    final goal = ref.watch(stepGoalProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text('HEALTH DATA', style: textTheme.labelSmall),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('health.list'),
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.lg,
            FitSpacing.screen,
            FitSpacing.xl,
          ),
          children: <Widget>[
            Text('Health Connect', style: textTheme.displayMedium),
            const SizedBox(height: FitSpacing.sm),
            Text(
              'FITOS uses your activity, training, recovery and body data to make your daily recommendations more useful. It only reads; nothing is written back, sent to a server or to any AI service.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: FitSpacing.lg),
            conn.when(
              loading: () => Text(
                'Checking…',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              error: (_, __) => _Unsupported(
                key: const ValueKey('health.error'),
                text: 'Could not reach Health Connect. Try again in a moment.',
                onRetry: () =>
                    ref.read(healthConnectionProvider.notifier).refresh(),
              ),
              data: (c) => _Body(state: c, snapshot: snapshot),
            ),
            const SizedBox(height: FitSpacing.xl),
            HairlineSection(
              label: 'Daily step goal',
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${_group(goal)} steps',
                      key: const ValueKey('health.stepGoal'),
                      style: textTheme.displaySmall,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('health.stepGoal.minus'),
                    onPressed: goal > 2000
                        ? () =>
                            ref.read(stepGoalProvider.notifier).set(goal - 1000)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    key: const ValueKey('health.stepGoal.plus'),
                    onPressed: goal < 30000
                        ? () =>
                            ref.read(stepGoalProvider.notifier).set(goal + 1000)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _group(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.snapshot});

  final HealthConnectionState state;
  final HealthSnapshot? snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(healthConnectionProvider.notifier);
    if (state.sdk == HealthSdkStatus.unavailable) {
      return const _Unsupported(
        key: ValueKey('health.unsupported'),
        text:
            'Health Connect is not available on this device. On Android 9–13 it is a separate app from Google Play; on Android 14 and later it is part of the system. FITOS works without it — you will not see steps, sleep or body metrics on Home.',
      );
    }
    if (state.sdk == HealthSdkStatus.updateRequired) {
      return _Unsupported(
        key: const ValueKey('health.updateRequired'),
        text:
            'Health Connect needs an update from Google Play before FITOS can read from it.',
        onRetry: controller.refresh,
        retryLabel: 'Check again',
      );
    }
    final connected = state.isConnected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          connected ? 'Connected' : 'Not connected',
          key: const ValueKey('health.status'),
          style: textTheme.displaySmall?.copyWith(
            color: connected ? FitColors.pine : FitColors.ink,
          ),
        ),
        if (snapshot != null && connected) ...<Widget>[
          const SizedBox(height: FitSpacing.xs),
          Text(
            snapshot!.fromCache
                ? 'Showing the last reading; Health Connect did not answer just now.'
                : 'Last read ${_ago(snapshot!.fetchedAt)}.',
            key: const ValueKey('health.freshness'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
        ],
        const SizedBox(height: FitSpacing.lg),
        for (final c in HealthCategory.values) _category(context, ref, c),
        const SizedBox(height: FitSpacing.md),
        Wrap(
          spacing: FitSpacing.sm,
          runSpacing: FitSpacing.sm,
          children: <Widget>[
            if (!connected)
              FilledButton(
                key: const ValueKey('health.connect'),
                onPressed: () =>
                    controller.connect(HealthCategory.values.toSet()),
                child: const Text('Connect'),
              ),
            OutlinedButton(
              key: const ValueKey('health.manage'),
              onPressed: () async {
                final opened = await controller.openSettings();
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open Health Connect from your phone settings to manage permissions.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Manage permissions'),
            ),
            OutlinedButton(
              key: const ValueKey('health.refresh'),
              onPressed: controller.refresh,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _category(BuildContext context, WidgetRef ref, HealthCategory c) {
    final textTheme = Theme.of(context).textTheme;
    final grant = state.categoryGrant(c);
    final kinds = HealthMetricKind.inCategory(c);
    final color = switch (grant) {
      CategoryGrant.all => FitColors.pine,
      CategoryGrant.partial => FitColors.amber,
      CategoryGrant.none => FitColors.ink60,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Divider(color: FitColors.rule, height: 1),
          const SizedBox(height: FitSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(child: Text(c.label, style: textTheme.titleMedium)),
              Text(
                HealthDataScreen.grantLabel(grant),
                key: ValueKey('health.${c.name}.grant'),
                style: textTheme.bodyMedium?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            kinds.map((k) => k.label).join(' · '),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
          if (grant != CategoryGrant.all)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: ValueKey('health.${c.name}.allow'),
                onPressed: () =>
                    ref.read(healthConnectionProvider.notifier).connect({c}),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Allow ${c.label.toLowerCase()}'),
              ),
            ),
        ],
      ),
    );
  }

  static String _ago(String iso) {
    final at = DateTime.tryParse(iso);
    if (at == null) return 'recently';
    final d = DateTime.now().toUtc().difference(at.toUtc());
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

class _Unsupported extends StatelessWidget {
  const _Unsupported({
    required this.text,
    this.onRetry,
    this.retryLabel = 'Try again',
    super.key,
  });

  final String text;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Not available', style: textTheme.displaySmall),
        const SizedBox(height: FitSpacing.sm),
        Text(text, style: textTheme.bodyMedium),
        if (onRetry != null) ...<Widget>[
          const SizedBox(height: FitSpacing.md),
          OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ],
    );
  }
}
