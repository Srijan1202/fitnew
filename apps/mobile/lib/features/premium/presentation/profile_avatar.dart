import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/avatars.dart';
import 'premium_providers.dart';
import 'rewards_providers.dart';

/// Phase 19 (ADR-027): the profile picture — one of the ten drawings, or the
/// initials — inside a gold rim when the user is premium.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.avatarId,
    required this.name,
    required this.premium,
    this.ember = false,
    this.size = 40,
    super.key,
  });

  final String? avatarId;
  final String? name;
  final bool premium;

  /// Beta 3.4: the Ember rim (a 60-day streak), worn instead of the gold one.
  final bool ember;
  final double size;

  static String initials(String? name) {
    final words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    final first = words.first.characters.first;
    final last = words.length > 1 ? words.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final def = avatarById(avatarId);
    final rimmed = premium || ember;
    final rim = rimmed ? size * 0.08 : 1.0;
    final (light, mid, deep) = ember
        ? (kEmberLight, kEmber, kEmberDeep)
        : (kGoldLight, kGold, kGoldDeep);
    final inner = size - 2 * rim;
    final letters = initials(name);
    final face = Container(
      width: inner,
      height: inner,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: def?.background ?? FitColors.paper2,
      ),
      alignment: Alignment.center,
      child: def != null
          ? Icon(def.icon, size: inner * 0.56, color: def.foreground)
          : letters.isEmpty
              ? Icon(
                  Icons.person_outline,
                  size: inner * 0.56,
                  color: FitColors.ink,
                )
              : Text(
                  letters,
                  style: TextStyle(
                    fontSize: inner * 0.36,
                    fontWeight: FontWeight.w600,
                    color: FitColors.ink,
                  ),
                ),
    );
    return Container(
      key: ValueKey(
        ember ? 'avatar.ember' : (premium ? 'avatar.premium' : 'avatar.free'),
      ),
      width: size,
      height: size,
      padding: EdgeInsets.all(rim),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: rimmed
            ? SweepGradient(colors: [light, mid, deep, mid, light])
            : null,
        color: rimmed ? null : FitColors.rule,
        boxShadow: rimmed
            ? [
                BoxShadow(
                  color: mid.withValues(alpha: 0.35),
                  blurRadius: size * 0.12,
                ),
              ]
            : null,
      ),
      child: face,
    );
  }
}

/// The Home header's way into Profile: the user's picture, gold-rimmed when
/// premium; the plain person icon until the profile has loaded.
class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider).value?.profile;
    final premium = ref.watch(isPremiumProvider) ?? false;
    final ember = ref.watch(emberRimProvider);
    return IconButton(
      key: const ValueKey('home.profile'),
      tooltip: 'Profile',
      onPressed: () => context.push(Routes.profile),
      icon: ProfileAvatar(
        avatarId: profile?.avatarId,
        name: profile?.displayName,
        premium: premium,
        ember: ember,
        size: 36,
      ),
    );
  }
}
