import 'package:flutter/material.dart';
import 'streak_rewards.dart';

/// Phase 19 (ADR-027, owner 2026-10-22): the ten profile pictures, drawn in
/// the app — an illustration on a coloured disc, crisp at any size, no image
/// files. The ids are the server's (contracts AVATARS); the last three are
/// premium and drawn in gold.
class AvatarDef {
  const AvatarDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.premium = false,
    this.reward,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final bool premium;

  /// Beta 3.4: a picture only a streak earns (null for the others).
  final StreakReward? reward;
}

/// The premium gold, for the three pictures and the rim.
const kGold = Color(0xFFC9A227);
const kGoldDeep = Color(0xFF8A6A12);
const kGoldLight = Color(0xFFF1D77A);

/// Beta 3.4: the streak rewards' ember, for their pictures, the rim and the
/// Ember theme.
const kEmber = Color(0xFFFF7A2F);
const kEmberDeep = Color(0xFFB8400F);
const kEmberLight = Color(0xFFFFC08A);

const kAvatars = <AvatarDef>[
  AvatarDef(
    id: 'dumbbell',
    label: 'Dumbbell',
    icon: Icons.fitness_center,
    background: Color(0xFF1E6B47),
    foreground: Color(0xFFEDEBE4),
  ),
  AvatarDef(
    id: 'runner',
    label: 'Runner',
    icon: Icons.directions_run,
    background: Color(0xFF2B5C8A),
    foreground: Color(0xFFEDEBE4),
  ),
  AvatarDef(
    id: 'yoga',
    label: 'Yoga',
    icon: Icons.self_improvement,
    background: Color(0xFF7A4E8C),
    foreground: Color(0xFFEDEBE4),
  ),
  AvatarDef(
    id: 'cyclist',
    label: 'Cyclist',
    icon: Icons.directions_bike,
    background: Color(0xFFA8641B),
    foreground: Color(0xFFEDEBE4),
  ),
  AvatarDef(
    id: 'swimmer',
    label: 'Swimmer',
    icon: Icons.pool,
    background: Color(0xFF1F7A86),
    foreground: Color(0xFFEDEBE4),
  ),
  AvatarDef(
    id: 'boxer',
    label: 'Boxer',
    icon: Icons.sports_mma,
    background: Color(0xFF9E2B21),
    foreground: Color(0xFFEDEBE4),
  ),
  AvatarDef(
    id: 'hiker',
    label: 'Hiker',
    icon: Icons.hiking,
    background: Color(0xFF5E5D58),
    foreground: Color(0xFFEDEBE4),
  ),
  AvatarDef(
    id: 'crown',
    label: 'Crown',
    icon: Icons.workspace_premium,
    background: Color(0xFF17171A),
    foreground: kGold,
    premium: true,
  ),
  AvatarDef(
    id: 'flame',
    label: 'Flame',
    icon: Icons.local_fire_department,
    background: Color(0xFF17171A),
    foreground: kGold,
    premium: true,
  ),
  AvatarDef(
    id: 'trophy',
    label: 'Trophy',
    icon: Icons.emoji_events,
    background: Color(0xFF17171A),
    foreground: kGold,
    premium: true,
  ),
  AvatarDef(
    id: 'spark',
    label: 'Spark',
    icon: Icons.whatshot,
    background: Color(0xFF241109),
    foreground: kEmber,
    reward: StreakReward.spark,
  ),
  AvatarDef(
    id: 'century',
    label: 'Century',
    icon: Icons.military_tech,
    background: Color(0xFF241109),
    foreground: kEmberLight,
    reward: StreakReward.century,
  ),
];

AvatarDef? avatarById(String? id) {
  for (final a in kAvatars) {
    if (a.id == id) return a;
  }
  return null;
}
