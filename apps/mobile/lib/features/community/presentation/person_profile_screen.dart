import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../premium/presentation/profile_avatar.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'community_screen.dart';

/// Beta 6.2 (C4, owner Q3): a friend's or club-mate's week — board data
/// only: the streak, this week, the 4 weeks before and the clubs you share.
class PersonProfileScreen extends ConsumerWidget {
  const PersonProfileScreen({required this.userId, this.handle, super.key});

  final String userId;

  /// From the board, so the title shows at once.
  final String? handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(personProfileProvider(userId));
    final p = profile.value;
    final name = p?.person.handle ?? handle;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text(name == null ? 'Profile' : '@$name'),
        actions: [
          if (p != null)
            PopupMenuButton<String>(
              key: const ValueKey('person.menu'),
              icon: const Icon(Icons.more_horiz),
              onSelected: (v) async {
                final api = ref.read(communityApiProvider);
                switch (v) {
                  case 'unfriend':
                    await api.unfriend(userId);
                  case 'block':
                    await api.block(userId);
                  case 'report':
                    await showReportSheet(context, ref, userId: userId);
                    return;
                }
                refreshCommunity(ref);
                if (context.mounted) context.popOrHome();
              },
              itemBuilder: (_) => [
                if (p.friend)
                  const PopupMenuItem(
                    key: ValueKey('person.unfriend'),
                    value: 'unfriend',
                    child: Text('Unfriend'),
                  ),
                const PopupMenuItem(
                  key: ValueKey('person.block'),
                  value: 'block',
                  child: Text('Block'),
                ),
                const PopupMenuItem(
                  key: ValueKey('person.report'),
                  value: 'report',
                  child: Text('Report'),
                ),
              ],
            ),
        ],
      ),
      body: FitBackdrop(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(FitSpacing.lg),
            child: Text(
              e is NotFound
                  ? 'You can see the week of your friends and of people in your clubs.'
                  : e is Offline
                      ? 'This needs a connection.'
                      : 'This is unavailable right now.',
              key: const ValueKey('person.problem'),
            ),
          ),
          data: (p) => _ProfileBody(profile: p),
        ),
      ),
    );
  }
}

String _short(String iso) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final d = DateTime.tryParse(iso);
  return d == null ? iso : '${d.day} ${months[d.month - 1]}';
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final PersonProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final p = profile;
    final since = p.friendsSince;
    final w = p.thisWeek;
    return ListView(
      key: const ValueKey('person.list'),
      padding: const EdgeInsets.all(FitSpacing.screen),
      children: [
        Row(
          children: [
            ProfileAvatar(
              avatarId: p.person.avatarId,
              name: p.person.handle,
              premium: false,
              size: 56,
            ),
            const SizedBox(width: FitSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${p.person.handle} ${flagOf(p.person.country)}',
                    style: t.titleLarge,
                  ),
                  Text(
                    p.friend
                        ? since == null
                            ? 'Friends'
                            : 'Friends since ${_short(since.toIso8601String())}'
                        : 'In ${p.clubsInCommon.map((c) => c.name).join(', ')} with you',
                    key: const ValueKey('person.relation'),
                    style: t.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: FitSpacing.lg),
        Text('THIS WEEK', style: t.labelSmall),
        const SizedBox(height: FitSpacing.sm),
        Wrap(
          spacing: FitSpacing.sm,
          runSpacing: FitSpacing.sm,
          children: [
            _Stat(
              label: 'Streak',
              value: '${p.streak} ${p.streak == 1 ? 'day' : 'days'}',
              k: 'streak',
            ),
            _Stat(label: 'Gym', value: '${w.sessions}', k: 'sessions'),
            _Stat(label: 'Run', value: kmOf(w.runM), k: 'run'),
            _Stat(label: 'Active days', value: '${w.activeDays}', k: 'days'),
            if (w.keptPct != null)
              _Stat(label: 'Kept plan', value: '${w.keptPct}%', k: 'plan'),
          ],
        ),
        const SizedBox(height: FitSpacing.lg),
        Text('THE WEEKS BEFORE', style: t.labelSmall),
        const SizedBox(height: FitSpacing.sm),
        FitBlock(
          child: Column(
            children: [
              for (final (i, x) in p.weeks.reversed.indexed) ...[
                if (i > 0) const FitRule(),
                ListTile(
                  key: ValueKey('person.week.${x.weekFrom}'),
                  title: Text('Week of ${_short(x.weekFrom)}'),
                  subtitle: Text(
                    [
                      '${x.sessions} gym',
                      if (x.runM > 0) kmOf(x.runM),
                      '${x.activeDays} active ${x.activeDays == 1 ? 'day' : 'days'}',
                      if (x.keptPct != null) 'plan ${x.keptPct}%',
                    ].join(' · '),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Beta 6.3 (C3): a set message to a friend who has been quiet 3 days.
        if (p.nudge != null) ...[
          const SizedBox(height: FitSpacing.lg),
          _NudgeButton(profile: p),
        ],
        if (p.clubsInCommon.isNotEmpty && p.friend) ...[
          const SizedBox(height: FitSpacing.lg),
          Text('CLUBS YOU SHARE', style: t.labelSmall),
          const SizedBox(height: FitSpacing.sm),
          Text(p.clubsInCommon.map((c) => c.name).join(', ')),
        ],
        if (!p.friend) ...[
          const SizedBox(height: FitSpacing.lg),
          FilledButton.icon(
            key: const ValueKey('person.add'),
            icon: const Icon(Icons.add),
            label: const Text('Add friend'),
            onPressed: () async {
              final r = await ref
                  .read(communityApiProvider)
                  .addFriend(p.person.handle);
              refreshCommunity(ref);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      r.when(
                        ok: (s) => s == 'friends'
                            ? 'You are now friends.'
                            : 'Request sent.',
                        err: (f) => f.message,
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ],
        const SizedBox(height: FitSpacing.lg),
        Text(
          'Only counts: never their weights, food, body or where they ran.',
          style: t.bodySmall?.copyWith(color: FitColors.ink60),
        ),
      ],
    );
  }
}

class _NudgeButton extends ConsumerWidget {
  const _NudgeButton({required this.profile});

  final PersonProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    final why = switch (p.nudge) {
      NudgeState.active => 'They trained in the last 3 days.',
      NudgeState.sent => 'You nudged them this week.',
      _ => 'Sends: "time to move. A short session counts."',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('person.nudge'),
          icon: const Icon(Icons.waving_hand_outlined),
          label: Text('Nudge @${p.person.handle}'),
          onPressed: p.nudge != NudgeState.can
              ? null
              : () async {
                  final r = await ref
                      .read(communityApiProvider)
                      .nudge(p.person.userId);
                  ref.invalidate(personProfileProvider(p.person.userId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          r.when(
                            ok: (_) => 'Nudge sent.',
                            err: (f) => f.message,
                          ),
                        ),
                      ),
                    );
                  }
                },
        ),
        const SizedBox(height: FitSpacing.xs),
        Text(
          why,
          key: const ValueKey('person.nudge.why'),
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: FitColors.ink60),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.k});

  final String label;
  final String value;
  final String k;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FitBlock(
      padding: const EdgeInsets.symmetric(
        horizontal: FitSpacing.md,
        vertical: FitSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            key: ValueKey('person.stat.$k'),
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(label, style: t.bodySmall?.copyWith(color: FitColors.ink60)),
        ],
      ),
    );
  }
}
