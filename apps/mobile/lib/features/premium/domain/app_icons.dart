import 'streak_rewards.dart';

/// Beta 3.2 (ADR-027 amendment): the launcher icons FITOS offers. Standard
/// and White for everyone; Gold, Glow and Lime for premium. Each name is an
/// activity-alias `.Icon<Name>` in AndroidManifest.xml and a preview in
/// assets/brand/app_icons/ (both made by tool/app_icons.py).
enum AppIcon {
  standard('Standard', premium: false),
  white('White', premium: false),
  gold('Gold'),
  glow('Glow'),
  lime('Lime'),

  /// Beta 3.4: earned with a 30-day streak (not premium).
  blaze('Blaze', premium: false, reward: StreakReward.blazeIcon);

  const AppIcon(this.label, {this.premium = true, this.reward});

  final String label;
  final bool premium;

  /// A streak reward rather than a premium icon; null for the others.
  final StreakReward? reward;

  String get preview => 'assets/brand/app_icons/$name.png';

  static AppIcon? byName(String? name) {
    for (final icon in values) {
      if (icon.name == name) return icon;
    }
    return null;
  }
}
