import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../../shared/widgets/fit_mode_switch.dart';
import '../../premium/presentation/profile_avatar.dart';
import '../../privacy/presentation/policy_text.dart';
import '../domain/club_goals.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'feed_view.dart';

/// Beta 5.8 (ADR-057; owner 2026-11-08: "Friends / VIT leaderboard ... we
/// have to make world level"): friends, clubs and the world board. Nobody
/// sees anyone until they join with a handle; boards hold counts only.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(communityMeProvider);
    // Beta 6.7 (A2, ADR-046): like Training and Nutrition, Community starts
    // with its switch; no app bar.
    return Scaffold(
      body: FitBackdrop(
        child: SafeArea(
          bottom: false,
          child: me.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Problem(
              e is Forbidden && e.issue == 'feature-off'
                  ? 'Community is switched off for now.'
                  : e is Offline
                      ? 'Community needs a connection.'
                      : 'Community is unavailable right now.',
              onRetry: () => ref.invalidate(communityMeProvider),
            ),
            data: (m) => m.profile == null
                ? const JoinCommunityView()
                : _Joined(profile: m.profile!, incoming: m.incoming),
          ),
        ),
      ),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem(this.text, {required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(FitSpacing.screen),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                key: const ValueKey('community.problem'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: FitSpacing.md),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}

/* ------------------------------------------------------------- joining -- */

/// What joining means, then the handle, the country and the world choice.
class JoinCommunityView extends ConsumerStatefulWidget {
  const JoinCommunityView({super.key});

  @override
  ConsumerState<JoinCommunityView> createState() => _JoinState();
}

class _JoinState extends ConsumerState<JoinCommunityView> {
  final _handle = TextEditingController();
  String? _country;
  bool _onWorld = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final handle = normalizeHandle(_handle.text);
    if (!kHandlePattern.hasMatch(handle)) {
      setState(() => _error = 'Use 3–20 letters, numbers or _.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await ref.read(communityApiProvider).join(
          handle: handle,
          country: _country,
          onWorld: _onWorld,
          policyVersion: kPolicyVersion,
        );
    if (!mounted) return;
    r.when(
      ok: (_) => refreshCommunity(ref),
      err: (f) => setState(() {
        _busy = false;
        _error = switch (f) {
          Conflict(issue: 'taken') => 'That handle is taken.',
          Conflict(issue: 'outdated') =>
            'The privacy policy changed. Accept the new one in Profile › Privacy & data first.',
          _ => f.message,
        };
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: FitSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: FitColors.ink60),
              const SizedBox(width: FitSpacing.sm),
              Expanded(child: Text(text, style: t.bodyMedium)),
            ],
          ),
        );
    return ListView(
      key: const ValueKey('community.join'),
      // Room for the floating bar.
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.screen,
        FitSpacing.screen,
        112,
      ),
      children: [
        Text('TRAIN TOGETHER', style: t.labelSmall),
        const SizedBox(height: FitSpacing.xs),
        Text('Friends, clubs and the world board', style: t.displaySmall),
        const SizedBox(height: FitSpacing.md),
        FitBlock(
          padding: const EdgeInsets.all(FitSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What others see', style: t.titleMedium),
              line(
                Icons.person_outline,
                'Your handle, your profile picture and your country. Never your name or email.',
              ),
              line(
                Icons.fitness_center,
                'Gym sessions and run distance this week, and your streak.',
              ),
              const SizedBox(height: FitSpacing.md),
              Text('Never shared', style: t.titleMedium),
              line(
                Icons.lock_outline,
                'Weights, food, body measurements, photos, readiness, sleep, heart rate and run routes.',
              ),
              const SizedBox(height: FitSpacing.md),
              Text('Yours to control', style: t.titleMedium),
              line(
                Icons.public,
                'The world board is a separate choice, off unless you turn it on.',
              ),
              line(
                Icons.logout,
                'Leave any time: you are off every board and friends list at once.',
              ),
            ],
          ),
        ),
        const SizedBox(height: FitSpacing.lg),
        TextField(
          key: const ValueKey('community.join.handle'),
          controller: _handle,
          maxLength: 21,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Your handle',
            prefixText: '@',
            helperText: '3–20 letters, numbers or _. Others find you by it.',
            errorText: _error,
            counterText: '',
          ),
        ),
        const SizedBox(height: FitSpacing.md),
        FitGroup(
          children: [
            FitRow(
              key: const ValueKey('community.join.country'),
              icon: Icons.flag_outlined,
              title: 'Country',
              value: _country == null
                  ? 'Not shown'
                  : '${flagOf(_country)} ${kCountries[_country]}',
              onTap: () async {
                final c = await pickCountry(context, current: _country);
                if (c != null) setState(() => _country = c.isEmpty ? null : c);
              },
            ),
            FitRow(
              key: const ValueKey('community.join.world'),
              icon: Icons.public,
              title: 'Show me on the world board',
              trailing: Switch(
                key: const ValueKey('community.join.worldSwitch'),
                value: _onWorld,
                onChanged: (v) => setState(() => _onWorld = v),
              ),
              onTap: () => setState(() => _onWorld = !_onWorld),
            ),
          ],
        ),
        const SizedBox(height: FitSpacing.md),
        // Beta 6.5 (K0, owner 2026-11-22): sharing is on from joining.
        Text(
          'Your friends and your clubs will see the sessions you finish, your '
          'runs, records and streak milestones. Turn any of them off in '
          'Community settings.',
          key: const ValueKey('community.join.sharing'),
          style: t.bodyMedium,
        ),
        const SizedBox(height: FitSpacing.sm),
        Text(
          'Joining is your consent to share the above with other FITOS members '
          '(privacy policy, version $kPolicyVersion).',
          style: t.bodySmall?.copyWith(color: FitColors.ink60),
        ),
        const SizedBox(height: FitSpacing.md),
        FilledButton(
          key: const ValueKey('community.join.submit'),
          onPressed: _busy ? null : _join,
          child: Text(_busy ? 'Joining…' : 'Join Community'),
        ),
      ],
    );
  }
}

/// A country from the list, searchable; '' for "not shown"; null when closed.
Future<String?> pickCountry(BuildContext context, {String? current}) =>
    showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CountrySheet(current: current),
    );

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.current});

  final String? current;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = kCountries.entries
        .where((e) => q.isEmpty || e.value.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(FitSpacing.md),
            child: TextField(
              key: const ValueKey('community.country.search'),
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Find a country',
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (q.isEmpty)
                  ListTile(
                    key: const ValueKey('community.country.none'),
                    title: const Text('Do not show my country'),
                    trailing:
                        widget.current == null ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.of(context).pop(''),
                  ),
                for (final e in list)
                  ListTile(
                    key: ValueKey('community.country.${e.key}'),
                    leading: Text(
                      flagOf(e.key),
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(e.value),
                    trailing: widget.current == e.key
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(context).pop(e.key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------- joined -- */

class _Joined extends ConsumerWidget {
  const _Joined({required this.profile, required this.incoming});

  final CommunityProfile profile;
  final int incoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(communityTabProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.sm,
            FitSpacing.xs,
            FitSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: FitModeSwitch<CommunityTab>(
                  key: const ValueKey('community.tab'),
                  thumbKey: const ValueKey('community.tab.thumb'),
                  value: tab,
                  halves: const [
                    // Beta 6.3 (C1): what friends shared; first since 6.7.
                    FitModeHalf(
                      CommunityTab.feed,
                      'Feed',
                      Icons.chat_bubble_outline,
                      key: ValueKey('community.tab.feed'),
                    ),
                    FitModeHalf(
                      CommunityTab.boards,
                      'Boards',
                      Icons.leaderboard_outlined,
                      key: ValueKey('community.tab.boards'),
                    ),
                    FitModeHalf(
                      CommunityTab.clubs,
                      'Clubs',
                      Icons.flag_outlined,
                      key: ValueKey('community.tab.clubs'),
                    ),
                  ],
                  onChanged: ref.read(communityTabProvider.notifier).set,
                ),
              ),
              // Beta 6.7 (R1): requests, friends and invites.
              IconButton(
                key: const ValueKey('community.people.open'),
                tooltip: incoming > 0 ? 'People, $incoming waiting' : 'People',
                onPressed: () => context.push(Routes.communityPeople),
                icon: Badge(
                  key: const ValueKey('community.people.badge'),
                  isLabelVisible: incoming > 0,
                  label: Text('$incoming'),
                  child: const Icon(Icons.people_outline),
                ),
              ),
              IconButton(
                key: const ValueKey('community.settings'),
                tooltip: 'Community settings',
                icon: const Icon(Icons.tune),
                onPressed: () => context.push(Routes.communitySettings),
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: tab.index,
            children: [
              const FeedView(),
              _BoardsView(profile: profile),
              const _ClubsView(),
            ],
          ),
        ),
      ],
    );
  }
}

/* --------------------------------------------------------------- boards -- */

/// What every board ranks by. Beta 6.2 (C11): five choices, so a row of
/// chips that scrolls sideways. Beta 6.3 (C13): the week, the month or all
/// time above them.
class BoardMetricPicker extends ConsumerWidget {
  const BoardMetricPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(boardMetricProvider);
    final period = ref.watch(boardPeriodProvider);
    final t = Theme.of(context).textTheme;
    // Beta 6.7 (R2): one row. The period is a small menu at its start; the
    // metrics scroll beside it.
    return SingleChildScrollView(
      key: const ValueKey('community.metric'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          PopupMenuButton<BoardPeriod>(
            key: const ValueKey('community.period'),
            tooltip: 'Week, month or all time',
            initialValue: period,
            onSelected: ref.read(boardPeriodProvider.notifier).set,
            itemBuilder: (_) => [
              for (final p in BoardPeriod.values)
                PopupMenuItem<BoardPeriod>(
                  key: ValueKey('community.period.${p.wire}'),
                  value: p,
                  child: Text(p.label),
                ),
            ],
            child: Container(
              height: 32,
              padding: const EdgeInsets.only(left: 12, right: 6),
              decoration: BoxDecoration(
                border: Border.all(color: FitColors.accent),
                borderRadius: BorderRadius.all(FitRadius.small),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    period.label,
                    key: const ValueKey('community.period.shown'),
                    style: t.labelLarge?.copyWith(color: FitColors.accent),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: FitColors.accent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: FitSpacing.sm),
          for (final m in BoardMetric.values)
            Padding(
              padding: const EdgeInsets.only(right: FitSpacing.xs),
              child: ChoiceChip(
                key: ValueKey('community.metric.${m.wire}'),
                label: Text(m.label),
                selected: m == metric,
                showCheckmark: false,
                onSelected: (_) =>
                    ref.read(boardMetricProvider.notifier).set(m),
              ),
            ),
        ],
      ),
    );
  }
}

/// The board's heading: this week's dates, this month, or since joining.
String boardHeading(Board b) => switch (b.period) {
      BoardPeriod.week => 'THIS WEEK · ${_day(b.weekFrom)} – ${_day(b.weekTo)}',
      BoardPeriod.month =>
        'THIS MONTH · FROM ${_day(b.periodFrom ?? b.weekFrom)}',
      BoardPeriod.all => 'ALL TIME · SINCE JOINING COMMUNITY',
    };

String _day(String iso) {
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

/// One board: the week, its rows (yours marked), and your own place below
/// the top when you are further down.
class BoardBlock extends StatelessWidget {
  const BoardBlock({
    required this.board,
    required this.emptyText,
    this.onPerson,
    this.tagOf,
    super.key,
  });

  final Board board;
  final String emptyText;
  final void Function(BoardRow row)? onPerson;

  /// Beta 6.6 (L2): "Owner" or "Co-owner" by a club's board rows.
  final String? Function(String userId)? tagOf;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final rows = board.rows;
    final last = board.lastWeek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (last != null) ...[
          _LastWeek(last: last, metric: board.metric),
          const SizedBox(height: FitSpacing.lg),
        ],
        Text(
          boardHeading(board).toUpperCase(),
          key: const ValueKey('community.board.week'),
          style: t.labelSmall,
        ),
        const SizedBox(height: FitSpacing.sm),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
            child: Text(
              emptyText,
              key: const ValueKey('community.board.empty'),
              style: t.bodyMedium?.copyWith(color: FitColors.ink60),
            ),
          )
        else
          FitBlock(
            child: Column(
              children: [
                for (final (i, r) in rows.indexed) ...[
                  if (i > 0) const FitRule(),
                  _BoardLine(
                    row: r,
                    metric: board.metric,
                    onTap: onPerson,
                    tag: tagOf?.call(r.userId),
                  ),
                ],
              ],
            ),
          ),
        if (board.me != null) ...[
          const SizedBox(height: FitSpacing.sm),
          FitBlock(
            child: _BoardLine(
              row: board.me!,
              metric: board.metric,
              onTap: null,
              tag: tagOf?.call(board.me!.userId),
            ),
          ),
        ],
      ],
    );
  }
}

/// Beta 6.2 (C12): last week's top three and your place. Beta 6.7 (R3): a
/// podium, first in the middle and raised, with medal colours.
class _LastWeek extends StatelessWidget {
  const _LastWeek({required this.last, required this.metric});

  final LastWeek last;
  final BoardMetric metric;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mine = last.myLine;
    // Second, first, third: the winner in the middle.
    final byRank = {for (final r in last.podium) r.rank: r};
    final order = [2, 1, 3].where(byRank.containsKey).map((k) => byRank[k]!);
    return Column(
      key: const ValueKey('community.lastWeek'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'LAST WEEK · FROM ${_day(last.weekFrom)}'.toUpperCase(),
          style: t.labelSmall,
        ),
        const SizedBox(height: FitSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final r in order)
              Expanded(child: _Step(row: r, metric: metric)),
          ],
        ),
        if (mine != null) ...[
          const SizedBox(height: FitSpacing.sm),
          Text(
            mine,
            key: const ValueKey('community.lastWeek.me'),
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
        ],
      ],
    );
  }
}

/// One place on the podium: the person over a step as high as the place.
class _Step extends StatelessWidget {
  const _Step({required this.row, required this.metric});

  final BoardRow row;
  final BoardMetric metric;

  /// Gold, silver and bronze from the palette, so every theme keeps them.
  static Color medal(int rank) => switch (rank) {
        1 => FitColors.amber,
        2 => FitColors.ink60,
        _ => FitColors.oxide,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final first = row.rank == 1;
    final colour = medal(row.rank);
    return Padding(
      key: ValueKey('community.podium.${row.handle}'),
      padding: const EdgeInsets.symmetric(horizontal: FitSpacing.xs),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colour, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ProfileAvatar(
                avatarId: row.avatarId,
                name: row.handle,
                premium: false,
                size: first ? 56 : 44,
              ),
            ),
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            '@${row.handle}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            boardValue(row, metric),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.xs),
          Container(
            height: switch (row.rank) {
              1 => 56.0,
              2 => 40.0,
              _ => 28.0,
            },
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.18),
              border: Border(top: BorderSide(color: colour, width: 2)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Text(
              ordinal(row.rank),
              style: t.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colour,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardLine extends StatelessWidget {
  const _BoardLine({
    required this.row,
    required this.metric,
    this.onTap,
    this.tag,
  });

  final BoardRow row;
  final BoardMetric metric;
  final void Function(BoardRow row)? onTap;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final value = boardValue(row, metric);
    final shown = [tag, boardOther(row, metric)].whereType<String>();
    final other = shown.isEmpty ? null : shown.join(' · ');
    return InkWell(
      key: ValueKey('community.row.${row.handle}'),
      onTap: row.me || onTap == null ? null : () => onTap!(row),
      child: Container(
        color: row.me ? FitColors.accent.withValues(alpha: 0.10) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: FitSpacing.md,
          vertical: FitSpacing.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${row.rank}',
                key: ValueKey('community.rank.${row.handle}'),
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ProfileAvatar(
              avatarId: row.avatarId,
              name: row.handle,
              premium: false,
              size: 34,
            ),
            const SizedBox(width: FitSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${row.handle}${row.me ? ' (you)' : ''} ${flagOf(row.country)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall,
                  ),
                  if (other != null)
                    Text(
                      other,
                      style: t.bodySmall?.copyWith(color: FitColors.ink60),
                    ),
                ],
              ),
            ),
            Text(
              value,
              key: ValueKey('community.value.${row.handle}'),
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// A board that is loading, failed or ready.
class BoardLoader extends ConsumerWidget {
  const BoardLoader({
    required this.board,
    required this.emptyText,
    required this.onRetry,
    this.onPerson,
    this.tagOf,
    super.key,
  });

  final AsyncValue<Board> board;
  final String emptyText;
  final VoidCallback onRetry;
  final void Function(BoardRow row)? onPerson;
  final String? Function(String userId)? tagOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) => board.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(FitSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => _Problem(
          e is Offline
              ? 'The board needs a connection.'
              : 'The board is unavailable right now.',
          onRetry: onRetry,
        ),
        data: (b) => BoardBlock(
          board: b,
          emptyText: emptyText,
          onPerson: onPerson,
          tagOf: tagOf,
        ),
      );
}

/* ---------------------------------------------------------- one person -- */

/// What can be done about someone: add or unfriend, block, report.
Future<void> showPersonSheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String handle,
  bool friend = false,
}) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      useSafeArea: true,
      builder: (sheet) {
        Future<void> act(Future<void> Function() run) async {
          Navigator.of(sheet).pop();
          await run();
          refreshCommunity(ref);
        }

        final api = ref.read(communityApiProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  '@$handle',
                  style: Theme.of(sheet).textTheme.titleMedium,
                ),
              ),
              if (!friend)
                ListTile(
                  key: const ValueKey('community.person.add'),
                  leading: const Icon(Icons.add),
                  title: const Text('Add friend'),
                  onTap: () => act(() async {
                    final r = await api.addFriend(handle);
                    if (context.mounted) {
                      _snack(
                        context,
                        r.when(
                          ok: (s) => s == 'friends'
                              ? 'You are now friends.'
                              : 'Request sent.',
                          err: (f) => f.message,
                        ),
                      );
                    }
                  }),
                )
              else
                ListTile(
                  key: const ValueKey('community.person.unfriend'),
                  leading: const Icon(Icons.remove_circle_outline),
                  title: const Text('Unfriend'),
                  onTap: () => act(() => api.unfriend(userId)),
                ),
              ListTile(
                key: const ValueKey('community.person.block'),
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Block'),
                subtitle: const Text('They cannot find, add or see you.'),
                onTap: () => act(() => api.block(userId)),
              ),
              ListTile(
                key: const ValueKey('community.person.report'),
                leading: const Icon(Icons.error_outline),
                title: const Text('Report'),
                onTap: () {
                  Navigator.of(sheet).pop();
                  showReportSheet(context, ref, userId: userId);
                },
              ),
            ],
          ),
        );
      },
    );

void _snack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Why, and an optional note, to the FITOS team.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  String? userId,
  String? clubId,
}) async {
  final reason = await showModalBottomSheet<ReportReason>(
    useRootNavigator: true,
    context: context,
    useSafeArea: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('What is wrong?')),
          for (final r in ReportReason.values)
            if (clubId == null || r != ReportReason.handle)
              if (userId == null || r != ReportReason.clubName)
                ListTile(
                  key: ValueKey('community.report.${r.wire}'),
                  title: Text(r.label),
                  onTap: () => Navigator.of(sheet).pop(r),
                ),
        ],
      ),
    ),
  );
  if (reason == null) return;
  final r = await ref
      .read(communityApiProvider)
      .report(userId: userId, clubId: clubId, reason: reason);
  if (context.mounted) {
    _snack(
      context,
      r.when(ok: (_) => 'Reported. Thank you.', err: (f) => f.message),
    );
  }
}

/* ---------------------------------------------------------------- clubs -- */

class _ClubsView extends ConsumerWidget {
  const _ClubsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final clubs = ref.watch(clubsProvider);
    return RefreshIndicator(
      onRefresh: () async => refreshCommunity(ref),
      child: ListView(
        key: const ValueKey('community.clubs'),
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          FitSpacing.sm,
          FitSpacing.screen,
          112,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('community.club.new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Make a club'),
                  onPressed: () => _clubDialog(context, ref, create: true),
                ),
              ),
              const SizedBox(width: FitSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('community.club.join'),
                  onPressed: () => _clubDialog(context, ref, create: false),
                  child: const Text('Join with a code'),
                ),
              ),
            ],
          ),
          const SizedBox(height: FitSpacing.lg),
          ...clubs.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (e, _) => [
              _Problem(
                'Your clubs are unavailable right now.',
                onRetry: () => ref.invalidate(clubsProvider),
              ),
            ],
            data: (list) => list.isEmpty
                ? [
                    Text(
                      'No clubs yet. A club is any group: your hostel, your '
                      'gym, your running crew, anywhere in the world. Make '
                      'one and share its code, or join one with a code.',
                      key: const ValueKey('community.clubs.empty'),
                      style: t.bodyMedium?.copyWith(color: FitColors.ink60),
                    ),
                  ]
                : [
                    // Beta 6.7 (R5): the clubs you run first.
                    for (final c in [
                      ...list.where((c) => c.runs),
                      ...list.where((c) => !c.runs),
                    ]) ...[
                      ClubCard(club: c),
                      const SizedBox(height: FitSpacing.sm),
                    ],
                  ],
          ),
        ],
      ),
    );
  }
}

/// Beta 6.7 (R5): a club in the list — its mark, name, members and your
/// part, and one line of what's on (the match or the challenge's bar).
class ClubCard extends StatelessWidget {
  const ClubCard({required this.club, super.key});

  final Club club;

  /// Each club keeps one colour from the palette, by its id.
  static Color colourOf(String id) {
    final colours = [
      FitColors.accent,
      FitColors.pine,
      FitColors.amber,
      FitColors.sky,
      FitColors.oxide,
    ];
    return colours[id.codeUnits.fold<int>(0, (a, b) => a + b) % colours.length];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = club;
    final colour = colourOf(c.id);
    final role = switch (c.role) {
      ClubRole.owner => 'Owner',
      ClubRole.coOwner => 'Co-owner',
      ClubRole.member => null,
    };
    final now = c.now;
    return FitBlock(
      key: ValueKey('community.club.${c.id}'),
      padding: const EdgeInsets.all(FitSpacing.md),
      onTap: () => context.push(Routes.communityClub(c.id), extra: c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.all(FitRadius.small),
                ),
                child: Text(
                  c.name.characters.first.toUpperCase(),
                  style: t.titleMedium?.copyWith(
                    color: colour,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: FitSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleMedium,
                          ),
                        ),
                        if (c.seasonWinner) ...[
                          const SizedBox(width: FitSpacing.xs),
                          Icon(
                            Icons.emoji_events,
                            size: 16,
                            color: FitColors.amber,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      [
                        '${c.members} ${c.members == 1 ? 'member' : 'members'}',
                        if (role != null) role,
                      ].join(' · '),
                      key: ValueKey('community.club.${c.id}.meta'),
                      style: t.bodySmall?.copyWith(color: FitColors.ink60),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: FitColors.ink60),
            ],
          ),
          if (now != null) ...[
            const SizedBox(height: FitSpacing.sm),
            Row(
              children: [
                Icon(
                  now is ClubNowMatch
                      ? Icons.sports_score
                      : Icons.flag_outlined,
                  size: 16,
                  color: FitColors.accent,
                ),
                const SizedBox(width: FitSpacing.xs),
                Expanded(
                  child: Text(
                    now.line,
                    key: ValueKey('community.club.${c.id}.now'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
            if (now is ClubNowChallenge) ...[
              const SizedBox(height: FitSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  key: ValueKey('community.club.${c.id}.bar'),
                  value: now.progress,
                  minHeight: 4,
                  color: FitColors.accent,
                  backgroundColor: FitColors.rule,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Make a club (its name) or join one (its code).
Future<void> _clubDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool create,
}) async {
  final value = await askText(
    context,
    title: create ? 'Make a club' : 'Join a club',
    fieldKey: const ValueKey('community.club.field'),
    okKey: const ValueKey('community.club.ok'),
    ok: create ? 'Make' : 'Join',
    hint: create ? "e.g. VIT Men's Hostel" : 'ABCD-2345',
    maxLength: create ? 40 : 9,
    capitalization:
        create ? TextCapitalization.words : TextCapitalization.characters,
  );
  if (value == null || value.trim().isEmpty) return;
  final api = ref.read(communityApiProvider);
  final r = create ? await api.createClub(value) : await api.joinClub(value);
  if (!context.mounted) return;
  refreshCommunity(ref);
  r.when(
    ok: (c) => context.push(Routes.communityClub(c.id), extra: c),
    err: (f) => _snack(context, f.message),
  );
}

/* --------------------------------------------------------------- boards -- */

/// Beta 6.7 (R1, owner 2026-11-27): one board for friends, the person's
/// country or the world, with one set of controls (they were on two tabs).
class _BoardsView extends ConsumerWidget {
  const _BoardsView({required this.profile});

  final CommunityProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final metric = ref.watch(boardMetricProvider);
    var scope = ref.watch(boardScopeProvider);
    if (scope == BoardScope.country && profile.country == null) {
      scope = BoardScope.world;
    }
    final friendIds = {
      for (final f in ref.watch(friendListsProvider).value?.friends ??
          const <CommunityPerson>[])
        f.userId,
    };
    return RefreshIndicator(
      onRefresh: () async => refreshCommunity(ref),
      child: ListView(
        key: const ValueKey('community.boards'),
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          FitSpacing.xs,
          FitSpacing.screen,
          112,
        ),
        children: [
          SegmentedButton<BoardScope>(
            key: const ValueKey('community.scope'),
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(
                value: BoardScope.friends,
                label: Text(
                  'Friends',
                  key: ValueKey('community.scope.friends'),
                ),
              ),
              if (profile.country != null)
                ButtonSegment(
                  value: BoardScope.country,
                  label: Text(
                    '${flagOf(profile.country)} ${kCountries[profile.country] ?? profile.country}',
                    key: const ValueKey('community.scope.country'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const ButtonSegment(
                value: BoardScope.world,
                label: Text(
                  'World',
                  key: ValueKey('community.scope.world'),
                ),
              ),
            ],
            selected: {scope},
            onSelectionChanged: (v) =>
                ref.read(boardScopeProvider.notifier).set(v.first),
          ),
          const SizedBox(height: FitSpacing.sm),
          const BoardMetricPicker(),
          const SizedBox(height: FitSpacing.md),
          if (scope != BoardScope.friends && !profile.onWorld) ...[
            FitBlock(
              key: const ValueKey('community.world.off'),
              padding: const EdgeInsets.all(FitSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'You can see this board. Others see your handle, '
                      'country and counts here only if you choose to.',
                      style: t.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: FitSpacing.sm),
                  TextButton(
                    key: const ValueKey('community.world.join'),
                    onPressed: () async {
                      await ref
                          .read(communityApiProvider)
                          .update(onWorld: true);
                      refreshCommunity(ref);
                    },
                    child: const Text('Show me'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FitSpacing.md),
          ],
          if (scope == BoardScope.friends)
            BoardLoader(
              board: ref.watch(friendsBoardProvider(metric)),
              emptyText: 'Add friends to see their week here.',
              onRetry: () => ref.invalidate(friendsBoardProvider),
              // Beta 6.2 (C4): a friend's week.
              onPerson: (r) => friendIds.contains(r.userId)
                  ? context.push(
                      Routes.communityPerson(r.userId),
                      extra: r.handle,
                    )
                  : showPersonSheet(
                      context,
                      ref,
                      userId: r.userId,
                      handle: r.handle,
                    ),
            )
          else
            BoardLoader(
              board: ref.watch(
                worldBoardProvider(
                  (
                    metric,
                    scope == BoardScope.country ? profile.country : null,
                  ),
                ),
              ),
              emptyText: 'Nobody has counted anything here this week yet.',
              onRetry: () => ref.invalidate(worldBoardProvider),
              onPerson: (r) => showPersonSheet(
                context,
                ref,
                userId: r.userId,
                handle: r.handle,
              ),
            ),
          const SizedBox(height: FitSpacing.md),
          Text(
            'Counts only what the server can check: a gym session of 6 sets '
            'and 15 minutes (one a day), and runs recorded by GPS or a watch.',
            style: t.bodySmall?.copyWith(color: FitColors.ink60),
          ),
        ],
      ),
    );
  }
}

/// One line of text in a dialog; the dialog owns its controller, so it is
/// let go only once the dialog has closed.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required Key fieldKey,
  required Key okKey,
  required String ok,
  String? hint,
  String? initial,
  String? prefix,
  int? maxLength,
  TextCapitalization capitalization = TextCapitalization.none,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: title,
        fieldKey: fieldKey,
        okKey: okKey,
        ok: ok,
        hint: hint,
        initial: initial,
        prefix: prefix,
        maxLength: maxLength,
        capitalization: capitalization,
      ),
    );

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.fieldKey,
    required this.okKey,
    required this.ok,
    required this.hint,
    required this.initial,
    required this.prefix,
    required this.maxLength,
    required this.capitalization,
  });

  final String title;
  final Key fieldKey;
  final Key okKey;
  final String ok;
  final String? hint;
  final String? initial;
  final String? prefix;
  final int? maxLength;
  final TextCapitalization capitalization;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          key: widget.fieldKey,
          controller: _text,
          autofocus: true,
          autocorrect: false,
          textCapitalization: widget.capitalization,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixText: widget.prefix,
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: widget.okKey,
            onPressed: () => Navigator.of(context).pop(_text.text),
            child: Text(widget.ok),
          ),
        ],
      );
}
