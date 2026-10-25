import '../../../../core/feedback/app_feedback.dart';
import '../../../feedback/presentation/feedback_screen.dart';
import '../../../premium/domain/avatars.dart';
import '../../../premium/presentation/app_icon_controller.dart';
import '../../../premium/presentation/app_icon_picker.dart';
import '../../../premium/presentation/avatar_picker.dart';
import '../../../premium/presentation/premium_card.dart';
import '../../../premium/presentation/premium_providers.dart';
import '../../../premium/presentation/profile_avatar.dart';
import '../../../premium/presentation/theme_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/device_time_zone.dart';
import '../../../../core/config/env.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../../progress/domain/progress.dart';
import '../../../progress/presentation/progress_providers.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../data/profile_repository.dart';
import '../../domain/entities/profile.dart';
import '../widgets/mess_setting.dart';
import 'food_preferences_screen.dart' show FoodSettingRow;
import '../widgets/targets_display.dart';
import '../../../premium/domain/streak_rewards.dart';
import '../../../premium/presentation/rewards_providers.dart';
import '../../../premium/presentation/streak_rewards_ui.dart';
import '../../../home/presentation/controllers/home_providers.dart';

/// Profile (ADR-029, owner): laid out like iPhone Settings — who you are and
/// your targets at the top, what you are in small tiles, then every setting
/// as a grouped list, one tap from the top instead of under a long page.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    // Read so a theme change rebuilds this page.
    ref.watch(themeControllerProvider);
    final side = fitGlass ? FitSpacing.md : FitSpacing.screen;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text('Profile', style: textTheme.titleMedium),
        centerTitle: true,
        backgroundColor: fitGlass ? Colors.transparent : null,
      ),
      extendBodyBehindAppBar: fitGlass,
      body: FitBackdrop(
        child: SafeArea(
          child: async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(FitSpacing.screen),
              child: TargetsSkeleton(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(FitSpacing.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AuthFeedback.error(
                    (e is Failure ? e : const Unknown()).message,
                  ),
                  const SizedBox(height: FitSpacing.md),
                  FilledButton(
                    onPressed: () => ref.invalidate(profileControllerProvider),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
            // Every row built (not a lazy list): the page is short, and
            // Sign out must exist to be scrolled to.
            data: (view) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(side, FitSpacing.sm, side, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Header(view: view),
                  _PhoneTimeZone(stored: view.profile.timezone),
                  const SizedBox(height: FitSpacing.md),
                  _Targets(view: view),
                  const SizedBox(height: FitSpacing.lg),
                  const _Eyebrow('About you'),
                  _AboutTiles(profile: view.profile),
                  const SizedBox(height: FitSpacing.lg),
                  FitGroup(
                    children: <Widget>[
                      FitRow(
                        key: const ValueKey('profile.personalDetails'),
                        icon: Icons.person_outline,
                        title: 'Personal details',
                        onTap: () => context.push(Routes.personalDetails),
                      ),
                      MessSettingRow(mess: view.profile.mess),
                      const FoodSettingRow(),
                    ],
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  FitGroup(
                    label: 'Appearance',
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: fitGlass ? 14 : 0,
                          vertical: fitGlass ? 14 : FitSpacing.sm,
                        ),
                        child: const ThemePicker(),
                      ),
                      // Beta 3.2: hidden where the icon cannot change.
                      if (ref.watch(appIconControllerProvider).value != null)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: fitGlass ? 14 : 0,
                            vertical: fitGlass ? 14 : FitSpacing.sm,
                          ),
                          child: const AppIconPicker(),
                        ),
                    ],
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  FitGroup(
                    label: 'App',
                    children: <Widget>[
                      FitRow(
                        key: const ValueKey('profile.notifications'),
                        icon: Icons.notifications_none,
                        title: 'Notifications',
                        onTap: () => context.push(Routes.notifications),
                      ),
                      FitRow(
                        key: const ValueKey('profile.health'),
                        icon: Icons.favorite_border,
                        title: 'Health data',
                        onTap: () => context.push(Routes.healthData),
                      ),
                      FitRow(
                        key: const ValueKey('profile.timezone'),
                        icon: Icons.public,
                        title: 'Time zone',
                        value: view.profile.timezone,
                      ),
                      // Beta 3.4: streak rewards, and the Ember rim once earned.
                      Consumer(
                        builder: (context, ref, _) => FitRow(
                          key: const ValueKey('profile.rewards'),
                          icon: Icons.local_fire_department,
                          title: 'Streak rewards',
                          value:
                              '${ref.watch(earnedRewardsProvider).value?.length ?? 0} of ${StreakReward.values.length}',
                          onTap: () => showStreakRewards(
                            context,
                            best: ref.read(streakProvider).value?.best,
                          ),
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, _) => ref.watch(
                          rewardEarnedProvider(StreakReward.emberRim),
                        )
                            ? FitRow(
                                key: const ValueKey('profile.emberRim'),
                                icon: Icons.blur_circular,
                                title: 'Ember rim',
                                trailing: Switch(
                                  key: const ValueKey(
                                    'profile.emberRim.switch',
                                  ),
                                  value: ref.watch(emberRimSettingProvider),
                                  onChanged: (on) => ref
                                      .read(
                                        emberRimSettingProvider.notifier,
                                      )
                                      .set(on),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      // Beta 3.2: subtle sound and haptics, each switchable.
                      Consumer(
                        builder: (context, ref, _) => FitRow(
                          key: const ValueKey('profile.sounds'),
                          icon: Icons.volume_up_outlined,
                          title: 'Sounds',
                          trailing: Switch(
                            key: const ValueKey('profile.sounds.switch'),
                            value: ref.watch(feedbackSettingsProvider).sounds,
                            onChanged: (on) => ref
                                .read(feedbackSettingsProvider.notifier)
                                .setSounds(on),
                          ),
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, _) => FitRow(
                          key: const ValueKey('profile.haptics'),
                          icon: Icons.vibration,
                          title: 'Haptics',
                          trailing: Switch(
                            key: const ValueKey('profile.haptics.switch'),
                            value: ref.watch(feedbackSettingsProvider).haptics,
                            onChanged: (on) => ref
                                .read(feedbackSettingsProvider.notifier)
                                .setHaptics(on),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  FitGroup(
                    label: 'Account',
                    children: <Widget>[
                      const PremiumCard(),
                      FitRow(
                        key: const ValueKey('profile.privacy'),
                        icon: Icons.lock_outline,
                        title: 'Privacy & data',
                        onTap: () => context.push(Routes.privacy),
                      ),
                      FitRow(
                        key: const ValueKey('profile.feedback'),
                        icon: Icons.chat_bubble_outline,
                        title: 'Send feedback',
                        // Beta 3.6: a reply from the FITOS team is waiting.
                        value: switch (
                            ref.watch(feedbackUnreadProvider).value ?? 0) {
                          0 => null,
                          1 => '1 new reply',
                          final n => '$n new replies',
                        },
                        valueKey: const ValueKey('profile.feedback.unread'),
                        onTap: () => context.push(Routes.feedback),
                      ),
                    ],
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  FitGroup(
                    label: 'About',
                    children: <Widget>[
                      FitRow(
                        key: const ValueKey('profile.foodSources'),
                        icon: Icons.menu_book_outlined,
                        title: 'Food data sources',
                        onTap: () => context.push(Routes.foodSources),
                      ),
                    ],
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  FitGroup(
                    children: <Widget>[
                      FitRow(
                        key: const ValueKey('profile.signOut'),
                        icon: Icons.logout,
                        title: 'Sign out',
                        destructive: true,
                        onTap: () => _signOut(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  // Phase 6.6: which build talks to which backend, so a
                  // tester's report can name it. No secrets here.
                  Text(
                    'FITOS ${Env.appVersion} · ${Env.flavor} · ${Env.apiHost}',
                    key: const ValueKey('profile.build'),
                    textAlign: TextAlign.center,
                    style:
                        textTheme.labelSmall?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The picture (tap to change), the name, the goal and Premium.
class _Header extends ConsumerWidget {
  const _Header({required this.view});

  final ProfileView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final premium = ref.watch(isPremiumProvider) ?? false;
    final p = view.profile;
    final line = <String>[
      view.goal.goal.goalType.label,
      if (p.sex != null) p.sex!.label,
      if (p.birthDate != null && p.birthDate!.length >= 4)
        'born ${p.birthDate!.substring(0, 4)}',
    ].join(' · ');
    return FitBlock(
      glow: true,
      padding: const EdgeInsets.all(FitSpacing.md),
      flatPadding: const EdgeInsets.only(bottom: FitSpacing.sm),
      child: Row(
        children: <Widget>[
          // Phase 19 (ADR-027): the picture — tap to change it.
          InkWell(
            key: const ValueKey('profile.avatar'),
            customBorder: const CircleBorder(),
            onTap: () => showAvatarPicker(context),
            child: ProfileAvatar(
              avatarId: p.avatarId,
              name: p.displayName,
              premium: premium,
              ember: ref.watch(emberRimProvider),
              size: 68,
            ),
          ),
          const SizedBox(width: FitSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  p.displayName ?? 'No name yet',
                  key: const ValueKey('profile.displayName'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    color:
                        p.displayName == null ? FitColors.ink60 : FitColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(line, style: textTheme.bodyMedium),
                if (premium ||
                    ref.watch(rewardEarnedProvider(StreakReward.century)))
                  Padding(
                    padding: const EdgeInsets.only(top: FitSpacing.sm),
                    child: Wrap(
                      spacing: FitSpacing.xs,
                      runSpacing: FitSpacing.xs,
                      children: <Widget>[
                        if (premium) const _PremiumBadge(),
                        // Beta 3.4: a 100-day streak.
                        if (ref.watch(
                          rewardEarnedProvider(StreakReward.century),
                        ))
                          const CenturyBadge(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('profile.premiumBadge'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: kGold.withValues(alpha: 0.16),
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(color: kGold.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.workspace_premium, size: 14, color: kGold),
            const SizedBox(width: 4),
            Text(
              'PREMIUM',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: kGold),
            ),
          ],
        ),
      );
}

/// The daily targets with the way to change the goal.
class _Targets extends StatelessWidget {
  const _Targets({required this.view});

  final ProfileView view;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final targets = view.goal.targets;
    final change = OutlinedButton.icon(
      key: const ValueKey('profile.changeGoal'),
      onPressed: () => context.push(Routes.goalEditor),
      style: _outlined,
      icon: const Icon(Icons.flag_outlined, size: 18),
      label: const Text('Change goal'),
    );
    if (targets == null) return change;
    return FitBlock(
      padding: const EdgeInsets.all(FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('DAILY TARGETS', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.sm),
          TargetsDisplay(targets: targets),
          const SizedBox(height: FitSpacing.sm),
          Text(
            targets.isCustom
                ? 'Your own target since ${targets.effectiveFrom}'
                : 'Since ${targets.effectiveFrom} · ${targets.reason}',
            key: const ValueKey('profile.targetsLine'),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: FitSpacing.md),
          Wrap(
            spacing: FitSpacing.sm,
            runSpacing: FitSpacing.sm,
            children: <Widget>[
              change,
              OutlinedButton.icon(
                key: const ValueKey('profile.setTargets'),
                onPressed: () => context.push(Routes.targetsEditor),
                style: _outlined,
                icon: const Icon(Icons.tune, size: 18),
                label:
                    Text(targets.isCustom ? 'Edit my targets' : 'Set my own'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A group's eyebrow, outside its blocks.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          fitGlass ? FitSpacing.sm : 0,
          0,
          0,
          FitSpacing.sm,
        ),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
}

/// Phase 6.6 Gate 7: signing out wipes this phone's workout data, sync
/// queue included — which once deleted the queued end of a session FITOS
/// already had, leaving it "in progress" on the server and blocking every
/// later session. Give the queue one chance to reach FITOS; if anything is
/// still unsynced, say so and let the user choose.
Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(workoutRepositoryProvider);
  await repo.sync().timeout(const Duration(seconds: 8), onTimeout: () {});
  final status = await repo.syncStatus();
  if (!status.clean) {
    if (!context.mounted) return;
    final n = status.pending + status.parked;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('signOut.unsynced'),
        title: const Text('Unsynced workout changes'),
        content: Text(
          '$n ${n == 1 ? 'change has' : 'changes have'} not reached FITOS yet. '
          'Signing out deletes ${n == 1 ? 'it' : 'them'} from this phone — '
          'including the end of any session that has not synced. '
          'Stay signed in and let it sync first?',
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey('signOut.anyway'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out anyway'),
          ),
          FilledButton(
            key: const ValueKey('signOut.stay'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay signed in'),
          ),
        ],
      ),
    );
    if (go != true) return;
  }
  await ref.read(authControllerProvider.notifier).signOut();
}

// A getter: built on each read, so it follows the palette.
ButtonStyle get _outlined => OutlinedButton.styleFrom(
      foregroundColor: FitColors.ink,
      side: BorderSide(color: FitColors.ink),
      minimumSize: const Size(88, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(FitRadius.small),
      ),
    );

/// What FITOS knows about you, as small tiles — the trend weight first
/// (§13.2: the trend is the headline, the latest raw reading small beneath).
class _AboutTiles extends ConsumerWidget {
  const _AboutTiles({required this.profile});

  final UserProfileDetail profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final trend = ref
        .watch(progressSummaryProvider(ProgressWindow.d30))
        .value
        ?.summary
        ?.weight
        .currentTrendKg;
    Widget tile(String label, Widget value, [Widget? under]) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: fitGlass ? 14 : FitSpacing.sm,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label.toUpperCase(), style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              value,
              if (under != null) under,
            ],
          ),
        );
    Widget big(String text) => Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium,
        );
    final tiles = <Widget>[
      if (trend != null || profile.latestWeightKg != null)
        tile(
          'Weight',
          Text(
            trend == null
                ? 'Trend after your next readings'
                : '${trend.toStringAsFixed(1)} kg trend',
            key: const ValueKey('profile.weight.trend'),
            style: trend == null
                ? textTheme.bodyMedium?.copyWith(color: FitColors.ink60)
                : textTheme.titleMedium,
          ),
          profile.latestWeightKg == null
              ? null
              : Text(
                  'Latest reading ${profile.latestWeightKg} kg',
                  key: const ValueKey('profile.weight.raw'),
                  style: textTheme.bodySmall?.copyWith(color: FitColors.ink35),
                ),
        ),
      if (profile.heightCm != null)
        tile('Height', big('${profile.heightCm} cm')),
      if (profile.trainingDaysPerWeek != null)
        tile('Training', big('${profile.trainingDaysPerWeek} days / week')),
      if (profile.experienceLevel != null)
        tile('Experience', big(profile.experienceLevel!.label)),
      if (profile.activityLevel != null)
        tile('Outside the gym', big(profile.activityLevel!.label)),
      if (profile.trainingLocation != null)
        tile('Trains at', big(profile.trainingLocation!.label)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FitTileGrid(tiles: tiles, margin: EdgeInsets.zero),
        if (profile.equipment.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              fitGlass ? FitSpacing.sm : 0,
              FitSpacing.sm,
              0,
              0,
            ),
            child: Text(
              'Equipment: ${profile.equipment.map((e) => e.label).join(', ')}',
              style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
            ),
          ),
      ],
    );
  }
}

/// The day boundaries follow the stored time zone (§9.1). When this phone is
/// in another zone, offer it — never change it silently (audit 2026-10-20).
class _PhoneTimeZone extends ConsumerStatefulWidget {
  const _PhoneTimeZone({required this.stored});

  final String stored;

  @override
  ConsumerState<_PhoneTimeZone> createState() => _PhoneTimeZoneState();
}

class _PhoneTimeZoneState extends ConsumerState<_PhoneTimeZone> {
  bool _saving = false;
  String? _error;

  Future<void> _use(String zone) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await ref
        .read(profileControllerProvider.notifier)
        .savePersonalDetails(PersonalDetailsChange(timezone: zone));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = failure?.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(deviceTimeZoneProvider);
    if (phone == null || phone == widget.stored) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: FitSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'This phone is set to $phone. Your days run on ${widget.stored}.',
            key: const ValueKey('profile.timezone.differs'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
          TextButton(
            key: const ValueKey('profile.timezone.usePhone'),
            onPressed: _saving ? null : () => _use(phone),
            child: Text(_saving ? 'Saving…' : "Use this phone's time zone"),
          ),
          if (_error != null)
            Text(
              _error!,
              key: const ValueKey('profile.timezone.error'),
              style: textTheme.bodyMedium?.copyWith(color: FitColors.oxide),
            ),
        ],
      ),
    );
  }
}
