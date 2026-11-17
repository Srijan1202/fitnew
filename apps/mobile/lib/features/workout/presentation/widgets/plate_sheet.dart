import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/plates.dart';
import '../controllers/rest_timer.dart';

/// Beta 6.4 (N3, owner Q2): the gym's bar and plates, kept on the phone.
class GymPlatesController extends Notifier<GymPlates> {
  static const key = 'plates.v1';

  @override
  GymPlates build() {
    final raw = ref.watch(sharedPreferencesProvider).value?.getString(key);
    if (raw == null) return GymPlates.standard;
    try {
      return GymPlates.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return GymPlates.standard;
    }
  }

  Future<void> set(GymPlates gym) async {
    state = gym;
    await ref
        .read(sharedPreferencesProvider)
        .value
        ?.setString(key, jsonEncode(gym.toJson()));
  }
}

final gymPlatesProvider =
    NotifierProvider<GymPlatesController, GymPlates>(GymPlatesController.new);

/// "100 kg: 20 kg bar + 25 + 15 each side", drawn, for a weight that can be
/// changed in 2.5 kg steps.
Future<void> showPlateSheet(BuildContext context, {double? kg}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _PlateSheet(start: kg),
    );

class _PlateSheet extends ConsumerStatefulWidget {
  const _PlateSheet({this.start});

  final double? start;

  @override
  ConsumerState<_PlateSheet> createState() => _PlateSheetState();
}

class _PlateSheetState extends ConsumerState<_PlateSheet> {
  late double _kg = widget.start ?? 60;

  void _step(double by) => setState(() => _kg = (_kg + by).clamp(0, 500));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final gym = ref.watch(gymPlatesProvider);
    final a = platesFor(_kg, gym);
    final side = a.load.perSide;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.md,
        FitSpacing.screen,
        FitSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Plates', style: t.titleLarge),
          const SizedBox(height: FitSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                key: const ValueKey('plates.less'),
                tooltip: '2.5 kg less',
                onPressed: () => _step(-2.5),
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  '${kgText(_kg)} kg',
                  key: const ValueKey('plates.kg'),
                  textAlign: TextAlign.center,
                  style: t.displaySmall,
                ),
              ),
              IconButton.filledTonal(
                key: const ValueKey('plates.more'),
                tooltip: '2.5 kg more',
                onPressed: () => _step(2.5),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: FitSpacing.md),
          _BarDrawing(perSide: side),
          const SizedBox(height: FitSpacing.md),
          Text(
            side.isEmpty
                ? 'Just the ${kgText(gym.barKg)} kg bar'
                : '${kgText(gym.barKg)} kg bar + ${side.map(kgText).join(' + ')} each side',
            key: const ValueKey('plates.answer'),
            textAlign: TextAlign.center,
            style: t.titleMedium,
          ),
          if (!a.exact) ...[
            const SizedBox(height: FitSpacing.xs),
            Text(
              _notExact(a),
              key: const ValueKey('plates.notExact'),
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
          ],
          const SizedBox(height: FitSpacing.md),
          TextButton.icon(
            key: const ValueKey('plates.gym'),
            onPressed: () => showGymPlatesSheet(context),
            icon: const Icon(Icons.tune),
            label: Text('Your gym: ${gym.summary}'),
          ),
        ],
      ),
    );
  }

  String _notExact(PlateAnswer a) {
    final options = [
      if (a.below != null) '${kgText(a.below!)} kg',
      if (a.above != null) '${kgText(a.above!)} kg',
    ];
    return '${kgText(_kg)} kg can\'t be made with your plates. '
        'Nearest: ${options.join(' or ')}.';
  }
}

/// The plates on one side, heaviest by the collar, sized by weight.
class _BarDrawing extends StatelessWidget {
  const _BarDrawing({required this.perSide});

  final List<double> perSide;

  @override
  Widget build(BuildContext context) {
    Widget plate(String side, int i, double kg) => Container(
          key: ValueKey('plates.$side.$i.${kgText(kg)}'),
          width: kg >= 10 ? 16 : 12,
          height: 28 + 72 * (kg / 25).clamp(0.15, 1.0),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: kg >= 20
                ? FitColors.accent
                : kg >= 10
                    ? FitColors.ink
                    : FitColors.ink60,
            borderRadius: BorderRadius.circular(3),
          ),
        );
    final bar = Container(width: 60, height: 8, color: FitColors.ink60);
    return SizedBox(
      height: 104,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, p) in perSide.indexed.toList().reversed)
            plate('left', i, p),
          bar,
          for (final (i, p) in perSide.indexed) plate('right', i, p),
        ],
      ),
    );
  }
}

/// Training settings: the bar's weight and the plates the gym has.
Future<void> showGymPlatesSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => const _GymPlatesSheet(),
    );

class _GymPlatesSheet extends ConsumerWidget {
  const _GymPlatesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final gym = ref.watch(gymPlatesProvider);
    final c = ref.read(gymPlatesProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.md,
        FitSpacing.screen,
        FitSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bar and plates', style: t.titleLarge),
          const SizedBox(height: FitSpacing.md),
          Text('THE BAR', style: t.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Wrap(
            spacing: FitSpacing.xs,
            children: [
              for (final b in kBarWeights)
                ChoiceChip(
                  key: ValueKey('plates.bar.${kgText(b)}'),
                  label: Text('${kgText(b)} kg'),
                  selected: gym.barKg == b,
                  showCheckmark: false,
                  onSelected: (_) => c.set(gym.copyWith(barKg: b)),
                ),
            ],
          ),
          const SizedBox(height: FitSpacing.md),
          Text('PLATES YOUR GYM HAS (A PAIR OF EACH)', style: t.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Wrap(
            spacing: FitSpacing.xs,
            runSpacing: FitSpacing.xs,
            children: [
              for (final p in kPlateSizes)
                FilterChip(
                  key: ValueKey('plates.size.${kgText(p)}'),
                  label: Text('${kgText(p)} kg'),
                  selected: gym.plates.contains(p),
                  onSelected: (on) {
                    final next = on
                        ? [...gym.plates, p]
                        : gym.plates.where((x) => x != p).toList();
                    // At least one plate size stays.
                    if (next.isNotEmpty) c.set(gym.copyWith(plates: next));
                  },
                ),
            ],
          ),
          const SizedBox(height: FitSpacing.md),
          TextButton(
            key: const ValueKey('plates.reset'),
            onPressed: () => c.set(GymPlates.standard),
            child: const Text('Back to the standard set'),
          ),
        ],
      ),
    );
  }
}
