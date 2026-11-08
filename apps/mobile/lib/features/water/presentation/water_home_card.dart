import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_features.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/water.dart';
import 'water_providers.dart';

/// Beta 6.0 (F7, ADR-059): water on Home — the day's total against its
/// target, one tap for a glass (250 ml) and one to take a glass off. Tapping
/// the card opens other amounts and how the target is set. Nothing when the
/// admin switched water off.
class WaterHomeCard extends ConsumerWidget {
  const WaterHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureOnProvider(AppFeature.water))) {
      return const SizedBox.shrink();
    }
    final day = ref.watch(waterProvider).value;
    if (day == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final water = ref.read(waterProvider.notifier);
    final left = day.glassesLeft;
    final line = left == 0
        ? 'Target reached · ${waterAmount(day.targetMl)}'
        : 'of ${waterAmount(day.targetMl)} · '
            '$left ${left == 1 ? 'glass' : 'glasses'} to go';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.md,
        FitSpacing.screen,
        0,
      ),
      child: FitBlock(
        key: const ValueKey('home.water'),
        padding: const EdgeInsets.all(FitSpacing.md),
        onTap: () => _sheet(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  color: FitColors.accent,
                ),
                const SizedBox(width: FitSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WATER', style: t.labelSmall),
                      const SizedBox(height: 2),
                      Text(
                        waterAmount(day.ml),
                        key: const ValueKey('home.water.value'),
                        style: t.titleLarge,
                      ),
                      Text(
                        day.unsynced ? '$line · not synced yet' : line,
                        key: const ValueKey('home.water.line'),
                        style: t.bodySmall?.copyWith(color: FitColors.ink60),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('home.water.less'),
                  tooltip: 'Take off a glass',
                  onPressed:
                      day.ml == 0 ? null : () => water.add(-kWaterGlassMl),
                  icon: const Icon(Icons.remove),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('home.water.add'),
                  onPressed: day.ml >= kWaterMaxMl
                      ? null
                      : () => water.add(kWaterGlassMl),
                  icon: const Icon(Icons.add),
                  label: const Text('Glass'),
                ),
              ],
            ),
            const SizedBox(height: FitSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: const ValueKey('home.water.bar'),
                value: day.share,
                minHeight: 6,
                color: FitColors.accent,
                backgroundColor: FitColors.rule,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _sheet(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const _WaterSheet(),
      );
}

/// Other amounts, and how the target is set.
class _WaterSheet extends ConsumerWidget {
  const _WaterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(waterProvider).value;
    if (day == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final water = ref.read(waterProvider.notifier);
    Widget amount(int ml) => OutlinedButton(
          key: ValueKey('water.sheet.$ml'),
          onPressed: day.ml + ml > kWaterMaxMl ? null : () => water.add(ml),
          child: Text('+ ${waterAmount(ml)}'),
        );
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            0,
            FitSpacing.screen,
            FitSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Water today', style: t.titleLarge),
              const SizedBox(height: FitSpacing.xs),
              Text(
                '${waterAmount(day.ml)} of ${waterAmount(day.targetMl)}',
                key: const ValueKey('water.sheet.total'),
                style: t.bodyLarge,
              ),
              const SizedBox(height: FitSpacing.md),
              Wrap(
                spacing: FitSpacing.sm,
                runSpacing: FitSpacing.sm,
                children: [
                  amount(250),
                  amount(500),
                  amount(750),
                  amount(1000),
                  TextButton(
                    key: const ValueKey('water.sheet.less'),
                    onPressed:
                        day.ml == 0 ? null : () => water.add(-kWaterGlassMl),
                    child: const Text('− 250 ml'),
                  ),
                ],
              ),
              const SizedBox(height: FitSpacing.md),
              Text(
                day.fromWeight
                    ? 'Your target is 35 ml for each kg of your latest '
                        'weigh-in, to the nearest glass, between 1.5 and 4 L.'
                    : 'Your target is 2.5 L until you log a weigh-in; then '
                        'it is 35 ml for each kg.',
                key: const ValueKey('water.sheet.how'),
                style: t.bodySmall?.copyWith(color: FitColors.ink60),
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(
                'A guide: heat, sweat and food change what you need.',
                style: t.bodySmall?.copyWith(color: FitColors.ink60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
