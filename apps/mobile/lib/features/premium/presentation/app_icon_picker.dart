import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/app_icons.dart';
import '../domain/avatars.dart';
import 'app_icon_controller.dart';
import 'premium_providers.dart';
import 'premium_sheet.dart';

/// Beta 3.2 (ADR-027 amendment): Profile → Appearance → App icon. Standard
/// and White for everyone; Gold, Glow and Lime for premium (a lock, then the
/// premium sheet, for a free user). Hidden where the icon cannot change.
class AppIconPicker extends ConsumerWidget {
  const AppIconPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appIconControllerProvider).value;
    if (current == null) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final premium = ref.watch(isPremiumProvider) ?? false;
    return Column(
      key: const ValueKey('profile.appIcon'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('APP ICON', style: textTheme.labelSmall),
        const SizedBox(height: FitSpacing.sm),
        Wrap(
          spacing: FitSpacing.md,
          runSpacing: FitSpacing.sm,
          children: <Widget>[
            for (final icon in AppIcon.values)
              _IconTile(
                key: ValueKey('appIcon.${icon.name}'),
                icon: icon,
                selected: current == icon,
                locked: icon.premium && !premium,
                onTap: () async {
                  if (icon.premium && !premium) {
                    await showPremiumSheet(
                      context,
                      feature: 'The ${icon.label} app icon',
                    );
                    return;
                  }
                  final ok = await ref
                      .read(appIconControllerProvider.notifier)
                      .choose(icon);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Your phone did not change the icon.'),
                      ),
                    );
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: FitSpacing.sm),
        Text(
          'Your phone may close FITOS once while it changes the icon.',
          style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.selected,
    required this.locked,
    required this.onTap,
    super.key,
  });

  final AppIcon icon;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label:
          locked ? '${icon.label} app icon, premium' : '${icon.label} app icon',
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(
                  color: selected
                      ? (fitGlass ? FitColors.accent : FitColors.ink)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      child: Image.asset(icon.preview, fit: BoxFit.cover),
                    ),
                  ),
                  if (locked)
                    const Positioned(
                      right: 2,
                      top: 2,
                      child: Icon(Icons.lock, size: 14, color: kGoldDeep),
                    ),
                ],
              ),
            ),
            const SizedBox(height: FitSpacing.xs),
            Text(icon.label, style: textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
