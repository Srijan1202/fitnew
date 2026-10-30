import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/avatars.dart';
import 'premium_providers.dart';
import 'premium_sheet.dart';
import '../../running/domain/efforts.dart';
import '../domain/streak_rewards.dart';
import 'rewards_providers.dart';

/// Phase 19 (ADR-027, ADR-028), owner 2026-10-30: Profile → Theme.
/// Automatic first (Dark or Light with the phone, the default), then Dark,
/// Light, Cobalt and the green FITOS Dark and Light for everyone; Night,
/// Forest and Ocean for premium (a lock, then the premium sheet, for a free
/// user); the reward themes once earned.
class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final current = ref.watch(themeControllerProvider);
    final automatic = ref.watch(themeFollowsDeviceProvider);
    final premium = ref.watch(isPremiumProvider) ?? false;
    // Beta 4.2: a streak reward's id or a running badge's (the Road theme).
    final earned = ref.watch(earnedUnlocksProvider) ?? const <String>{};
    bool streakLocked(FitPalette p) =>
        p.reward != null && !earned.contains(p.reward);
    return Column(
      key: const ValueKey('profile.theme'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('THEME', style: textTheme.labelSmall),
        const SizedBox(height: FitSpacing.sm),
        Wrap(
          spacing: FitSpacing.md,
          runSpacing: FitSpacing.sm,
          children: <Widget>[
            _Swatch(
              key: const ValueKey('theme.auto'),
              palette: FitPalette.dark,
              half: FitPalette.light,
              label: 'Automatic',
              selected: automatic,
              locked: false,
              onTap: () =>
                  ref.read(themeControllerProvider.notifier).followDevice(),
            ),
            for (final p in FitPalette.all)
              _Swatch(
                key: ValueKey('theme.${p.id}'),
                palette: p,
                selected: !automatic && current.id == p.id,
                locked: (p.premium && !premium) || streakLocked(p),
                streakLock: p.reward != null,
                onTap: () async {
                  if (streakLocked(p)) {
                    final how = StreakReward.byId(p.reward)?.howToEarn ??
                        RunBadge.byId(p.reward)?.unlockHowTo ??
                        'Not unlocked yet.';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(how)),
                    );
                    return;
                  }
                  if (p.premium && !premium) {
                    await showPremiumSheet(
                      context,
                      feature: 'The ${p.label} theme',
                    );
                    return;
                  }
                  await ref.read(themeControllerProvider.notifier).choose(p);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.palette,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.streakLock = false,
    this.half,
    this.label,
    super.key,
  });

  /// Automatic: the right half shows this palette (Light beside Dark).
  final FitPalette? half;

  /// In place of the palette's name.
  final String? label;

  /// Beta 3.4: locked by a streak (🔥), not by premium.
  final bool streakLock;
  final FitPalette palette;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: locked
          ? '${palette.label} theme, ${streakLock ? 'streak reward' : 'premium'}'
          : '${label ?? palette.label} theme',
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              clipBehavior: fitGlass ? Clip.antiAlias : Clip.none,
              decoration: BoxDecoration(
                color: palette.paper,
                // ADR-029: rounded on the glass palettes.
                borderRadius: fitGlass
                    ? const BorderRadius.all(Radius.circular(12))
                    : null,
                border: Border.all(
                  color: selected
                      ? (fitGlass ? FitColors.accent : FitColors.ink)
                      : palette.rule,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Stack(
                children: <Widget>[
                  if (half case final h?)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 26,
                      child: ColoredBox(color: h.paper),
                    ),
                  Positioned(
                    left: 8,
                    top: 10,
                    child:
                        Container(width: 26, height: 4, color: palette.accent),
                  ),
                  Positioned(
                    left: 8,
                    top: 20,
                    child:
                        Container(width: 18, height: 4, color: palette.ink60),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Row(
                      children: <Widget>[
                        for (final c in [
                          palette.pine,
                          palette.amber,
                          palette.oxide,
                        ])
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 3),
                            color: c,
                          ),
                      ],
                    ),
                  ),
                  if (locked)
                    Positioned(
                      right: 3,
                      top: 3,
                      child: Icon(
                        streakLock ? Icons.local_fire_department : Icons.lock,
                        size: 14,
                        color: streakLock ? kEmber : kGoldDeep,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: FitSpacing.xs),
            Text(label ?? palette.label, style: textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
