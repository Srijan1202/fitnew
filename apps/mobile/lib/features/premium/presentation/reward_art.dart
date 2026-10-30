import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../running/domain/efforts.dart';
import '../domain/app_icons.dart';
import '../domain/streak_rewards.dart';
import 'profile_avatar.dart';

/// Beta 4.8 (owner): a reward shows what it unlocks — the app icon, the
/// theme's colours, the picture or the rim; a running badge without a
/// reward shows its group's mark. Until earned it is dimmed with a lock on
/// top, so you see what you are working towards.
class RewardArt extends StatelessWidget {
  const RewardArt({
    required this.id,
    required this.earned,
    this.size = 48,
    super.key,
  });

  /// The streak reward's or running badge's id.
  final String id;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final art = _art();
    return SizedBox(
      key: ValueKey('reward.art.$id'),
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: earned ? art : Opacity(opacity: 0.45, child: art),
          ),
          if (!earned)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                key: ValueKey('reward.art.$id.lock'),
                width: size * 0.42,
                height: size * 0.42,
                decoration: BoxDecoration(
                  color: FitColors.paper2,
                  shape: BoxShape.circle,
                  border: Border.all(color: FitColors.rule),
                ),
                child: Icon(
                  Icons.lock,
                  size: size * 0.24,
                  color: FitColors.ink60,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _art() {
    for (final icon in AppIcon.values) {
      if (icon.unlockId == id) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.24),
          child: Image.asset(icon.preview, fit: BoxFit.cover),
        );
      }
    }
    for (final p in FitPalette.all) {
      if (p.reward == id) return _Swatch(palette: p, size: size);
    }
    final reward = StreakReward.byId(id);
    if (reward == StreakReward.emberRim) {
      return ProfileAvatar(
        avatarId: 'runner',
        name: null,
        premium: false,
        ember: true,
        size: size,
      );
    }
    if (reward != null) {
      return ProfileAvatar(
        avatarId: reward.id,
        name: null,
        premium: false,
        size: size,
      );
    }
    final badge = RunBadge.byId(id);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: earned ? FitColors.accent : FitColors.ink35,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        switch (badge?.group) {
          BadgeGroup.speed => Icons.bolt,
          BadgeGroup.lifetime => Icons.route,
          BadgeGroup.consistency => Icons.event_repeat,
          _ => Icons.military_tech,
        },
        size: size * 0.5,
        color: earned ? FitColors.accent : FitColors.ink60,
      ),
    );
  }
}

/// A theme as a small card: its canvas, an action bar in its accent, a line
/// of its ink.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette, required this.size});

  final FitPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: palette.rule),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.glow.withValues(alpha: 0.35),
            blurRadius: size * 0.2,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            height: size * 0.14,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(size * 0.07),
            ),
          ),
          SizedBox(height: size * 0.1),
          Container(
            width: size * 0.4,
            height: size * 0.08,
            color: palette.ink60,
          ),
        ],
      ),
    );
  }
}
