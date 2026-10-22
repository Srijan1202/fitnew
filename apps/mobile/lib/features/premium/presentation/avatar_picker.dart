import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/theme/tokens.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/avatars.dart';
import 'premium_providers.dart';
import 'premium_sheet.dart';
import 'profile_avatar.dart';

/// Phase 19 (ADR-027): choose one of the ten pictures, or the initials. The
/// three premium ones show a lock for free users and open the premium sheet.
Future<void> showAvatarPicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AvatarPicker(),
    );

class _AvatarPicker extends ConsumerStatefulWidget {
  const _AvatarPicker();

  @override
  ConsumerState<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<_AvatarPicker> {
  bool _busy = false;
  String? _error;

  Future<void> _choose(String? id, {required bool locked}) async {
    if (locked) {
      await showPremiumSheet(context, feature: 'This picture');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(premiumApiProvider).setAvatar(id);
    if (!mounted) return;
    switch (r) {
      case Ok():
        ref.invalidate(profileControllerProvider);
        Navigator.of(context).pop();
      case Err(:final failure):
        setState(() {
          _busy = false;
          _error = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final premium = ref.watch(isPremiumProvider) ?? false;
    final profile = ref.watch(profileControllerProvider).value?.profile;
    final current = profile?.avatarId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        0,
        FitSpacing.screen,
        FitSpacing.xl,
      ),
      child: Column(
        key: const ValueKey('avatar.picker'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('PROFILE PICTURE', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.md),
          Wrap(
            spacing: FitSpacing.md,
            runSpacing: FitSpacing.md,
            children: <Widget>[
              _Choice(
                key: const ValueKey('avatar.choice.none'),
                label: 'Initials',
                selected: current == null,
                onTap: _busy ? null : () => _choose(null, locked: false),
                child: ProfileAvatar(
                  avatarId: null,
                  name: profile?.displayName,
                  premium: premium,
                  size: 56,
                ),
              ),
              for (final a in kAvatars)
                _Choice(
                  key: ValueKey('avatar.choice.${a.id}'),
                  label: a.label,
                  selected: current == a.id,
                  locked: a.premium && !premium,
                  onTap: _busy
                      ? null
                      : () => _choose(a.id, locked: a.premium && !premium),
                  child: ProfileAvatar(
                    avatarId: a.id,
                    name: null,
                    premium: a.premium,
                    size: 56,
                  ),
                ),
            ],
          ),
          if (_error case final e?)
            Padding(
              padding: const EdgeInsets.only(top: FitSpacing.md),
              child: Text(
                e,
                style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
              ),
            ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
    this.locked = false,
    super.key,
  });

  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$label, premium' : label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 64,
          child: Column(
            children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Opacity(opacity: locked ? 0.55 : 1, child: child),
                  if (locked)
                    const Positioned(
                      right: -2,
                      bottom: -2,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: kGoldDeep,
                        child: Icon(Icons.lock, size: 12, color: Colors.white),
                      ),
                    ),
                  if (selected)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: FitColors.pine,
                        child: const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(
                label,
                style: textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
