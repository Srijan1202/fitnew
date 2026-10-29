import '../../running/domain/efforts.dart';
import 'streak_rewards.dart';

/// Beta 3.2 (ADR-027 amendment): the launcher icons FITOS offers. Standard
/// and White for everyone; Gold, Glow and Lime for premium; Blaze for a
/// 30-day streak; Finisher and 42 for running badges (beta 4.2). Each name is an
/// activity-alias `.Icon<Name>` in AndroidManifest.xml and a preview in
/// assets/brand/app_icons/ (both made by tool/app_icons.py).
enum AppIcon {
  standard('Standard', premium: false),
  white('White', premium: false),
  gold('Gold'),
  glow('Glow'),
  lime('Lime'),

  /// Beta 3.4: earned with a 30-day streak (not premium).
  blaze('Blaze', premium: false, reward: StreakReward.blazeIcon),

  /// Beta 4.2: earned with a first 10K run.
  finisher('Finisher', premium: false, badge: RunBadge.first10k),

  /// Beta 4.2: earned with a first marathon.
  fortyTwo('42', premium: false, badge: RunBadge.firstMarathon),

  /// Beta 4.5: earned with a 5K under 20 minutes.
  bolt('Bolt', premium: false, badge: RunBadge.speed5k20);

  const AppIcon(
    this.label, {
    this.premium = true,
    this.reward,
    this.badge,
  });

  final String label;
  final bool premium;

  /// A streak reward rather than a premium icon; null for the others.
  final StreakReward? reward;

  /// Beta 4.2: a running badge's reward; null for the others.
  final RunBadge? badge;

  /// The earned reward or badge id that unlocks it; null when none does.
  String? get unlockId => reward?.id ?? badge?.id;

  /// "Reach a 30-day streak…" / "Run 10K in one go…".
  String? get howToEarn => reward?.howToEarn ?? badge?.unlockHowTo;

  String get preview => 'assets/brand/app_icons/$name.png';

  static AppIcon? byName(String? name) {
    for (final icon in values) {
      if (icon.name == name) return icon;
    }
    return null;
  }
}
