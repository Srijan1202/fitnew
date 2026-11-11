import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/failure.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../../shared/widgets/fit_mode_switch.dart';
import '../../premium/presentation/profile_avatar.dart';
import '../../privacy/presentation/policy_text.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'invite_qr.dart';

/// Beta 5.8 (ADR-057; owner 2026-11-08: "Friends / VIT leaderboard ... we
/// have to make world level"): friends, clubs and the world board. Nobody
/// sees anyone until they join with a handle; boards hold counts only.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(communityMeProvider);
    final joined = me.value?.joined ?? false;
    return Scaffold(
      appBar: AppBar(
        // Beta 5.9 (owner): Community is the last tab, so no back button.
        automaticallyImplyLeading: false,
        title: const Text('Community'),
        actions: [
          if (joined)
            IconButton(
              key: const ValueKey('community.settings'),
              tooltip: 'Community settings',
              icon: const Icon(Icons.tune),
              onPressed: () => context.push(Routes.communitySettings),
            ),
        ],
      ),
      body: FitBackdrop(
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
            FitSpacing.screen,
            FitSpacing.sm,
          ),
          child: FitModeSwitch<CommunityTab>(
            key: const ValueKey('community.tab'),
            thumbKey: const ValueKey('community.tab.thumb'),
            value: tab,
            halves: [
              FitModeHalf(
                CommunityTab.friends,
                incoming > 0 ? 'Friends · $incoming' : 'Friends',
                Icons.person_outline,
                key: const ValueKey('community.tab.friends'),
              ),
              const FitModeHalf(
                CommunityTab.clubs,
                'Clubs',
                Icons.flag_outlined,
                key: ValueKey('community.tab.clubs'),
              ),
              const FitModeHalf(
                CommunityTab.world,
                'World',
                Icons.public,
                key: ValueKey('community.tab.world'),
              ),
            ],
            onChanged: ref.read(communityTabProvider.notifier).set,
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: tab.index,
            children: [
              const _FriendsView(),
              const _ClubsView(),
              _WorldView(profile: profile),
            ],
          ),
        ),
      ],
    );
  }
}

/* --------------------------------------------------------------- boards -- */

/// What every board ranks by. Beta 6.2 (C11): five choices, so a row of
/// chips that scrolls sideways.
class BoardMetricPicker extends ConsumerWidget {
  const BoardMetricPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(boardMetricProvider);
    return SingleChildScrollView(
      key: const ValueKey('community.metric'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
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
    super.key,
  });

  final Board board;
  final String emptyText;
  final void Function(BoardRow row)? onPerson;

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
          'THIS WEEK · ${_day(board.weekFrom)} – ${_day(board.weekTo)}'
              .toUpperCase(),
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
                  _BoardLine(row: r, metric: board.metric, onTap: onPerson),
                ],
              ],
            ),
          ),
        if (board.me != null) ...[
          const SizedBox(height: FitSpacing.sm),
          FitBlock(
            child:
                _BoardLine(row: board.me!, metric: board.metric, onTap: null),
          ),
        ],
      ],
    );
  }
}

/// Beta 6.2 (C12): last week's top three and your place.
class _LastWeek extends StatelessWidget {
  const _LastWeek({required this.last, required this.metric});

  final LastWeek last;
  final BoardMetric metric;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mine = last.myLine;
    return Column(
      key: const ValueKey('community.lastWeek'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'LAST WEEK · FROM ${_day(last.weekFrom)}'.toUpperCase(),
          style: t.labelSmall,
        ),
        const SizedBox(height: FitSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in last.podium)
              Expanded(
                child: Column(
                  key: ValueKey('community.podium.${r.handle}'),
                  children: [
                    ProfileAvatar(
                      avatarId: r.avatarId,
                      name: r.handle,
                      premium: false,
                      size: r.rank == 1 ? 48 : 40,
                    ),
                    const SizedBox(height: FitSpacing.xs),
                    Text(
                      ordinal(r.rank),
                      style: t.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: r.rank == 1 ? FitColors.accent : null,
                      ),
                    ),
                    Text(
                      '@${r.handle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall,
                    ),
                    Text(
                      boardValue(r, metric),
                      style: t.bodySmall?.copyWith(color: FitColors.ink60),
                    ),
                  ],
                ),
              ),
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

class _BoardLine extends StatelessWidget {
  const _BoardLine({required this.row, required this.metric, this.onTap});

  final BoardRow row;
  final BoardMetric metric;
  final void Function(BoardRow row)? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final value = boardValue(row, metric);
    final other = boardOther(row, metric);
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
    super.key,
  });

  final AsyncValue<Board> board;
  final String emptyText;
  final VoidCallback onRetry;
  final void Function(BoardRow row)? onPerson;

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
        data: (b) =>
            BoardBlock(board: b, emptyText: emptyText, onPerson: onPerson),
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

/* -------------------------------------------------------------- friends -- */

class _FriendsView extends ConsumerWidget {
  const _FriendsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final metric = ref.watch(boardMetricProvider);
    final lists = ref.watch(friendListsProvider).value;
    final api = ref.read(communityApiProvider);
    final friendIds = {
      for (final f in lists?.friends ?? const <CommunityPerson>[]) f.userId,
    };
    return RefreshIndicator(
      onRefresh: () async => refreshCommunity(ref),
      child: ListView(
        key: const ValueKey('community.friends'),
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          FitSpacing.sm,
          FitSpacing.screen,
          112,
        ),
        children: [
          if (lists != null && lists.incoming.isNotEmpty) ...[
            Text('FRIEND REQUESTS', style: t.labelSmall),
            const SizedBox(height: FitSpacing.sm),
            FitBlock(
              child: Column(
                children: [
                  for (final p in lists.incoming)
                    ListTile(
                      key: ValueKey('community.incoming.${p.handle}'),
                      leading: ProfileAvatar(
                        avatarId: p.avatarId,
                        name: p.handle,
                        premium: false,
                        size: 34,
                      ),
                      title: Text('@${p.handle} ${flagOf(p.country)}'),
                      onTap: () => context.push(
                        Routes.communityPerson(p.userId),
                        extra: p.handle,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey('community.decline.${p.handle}'),
                            tooltip: 'Decline',
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await api.unfriend(p.userId);
                              refreshCommunity(ref);
                            },
                          ),
                          IconButton(
                            key: ValueKey('community.accept.${p.handle}'),
                            tooltip: 'Accept',
                            icon: const Icon(Icons.check),
                            onPressed: () async {
                              await api.accept(p.userId);
                              refreshCommunity(ref);
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: FitSpacing.lg),
          ],
          Row(
            children: [
              const Expanded(child: BoardMetricPicker()),
              const SizedBox(width: FitSpacing.sm),
              IconButton.filledTonal(
                key: const ValueKey('community.addFriend'),
                tooltip: 'Add a friend',
                icon: const Icon(Icons.add),
                onPressed: () => _addFriend(context, ref),
              ),
            ],
          ),
          const SizedBox(height: FitSpacing.md),
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
          ),
          if (lists != null && lists.outgoing.isNotEmpty) ...[
            const SizedBox(height: FitSpacing.lg),
            Text('WAITING FOR AN ANSWER', style: t.labelSmall),
            for (final p in lists.outgoing)
              ListTile(
                key: ValueKey('community.outgoing.${p.handle}'),
                contentPadding: EdgeInsets.zero,
                title: Text('@${p.handle}'),
                trailing: TextButton(
                  onPressed: () async {
                    await api.unfriend(p.userId);
                    refreshCommunity(ref);
                  },
                  child: const Text('Cancel'),
                ),
              ),
          ],
          const SizedBox(height: FitSpacing.lg),
          _InviteLine(
            handle: ref.watch(communityMeProvider).value?.profile?.handle,
          ),
        ],
      ),
    );
  }
}

/// Tell a friend your handle (the share sheet).
class _InviteLine extends StatelessWidget {
  const _InviteLine({required this.handle});

  final String? handle;

  @override
  Widget build(BuildContext context) => handle == null
      ? const SizedBox.shrink()
      : Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('community.invite'),
                icon: const Icon(Icons.ios_share),
                label: Text('Invite a friend · @$handle'),
                // Beta 6.2 (C15): the link opens FITOS on "Add @you?".
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: 'Train with me on FITOS: ${friendInviteUrl(handle!)}',
                  ),
                ),
              ),
            ),
            const SizedBox(width: FitSpacing.sm),
            IconButton.outlined(
              key: const ValueKey('community.invite.qr'),
              tooltip: 'My QR code',
              icon: const Icon(Icons.qr_code_2),
              onPressed: () => showHandleQr(context, handle!),
            ),
          ],
        );
}

Future<void> _addFriend(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: const _AddFriendSheet(),
      ),
    );

class _AddFriendSheet extends ConsumerStatefulWidget {
  const _AddFriendSheet();

  @override
  ConsumerState<_AddFriendSheet> createState() => _AddFriendState();
}

class _AddFriendState extends ConsumerState<_AddFriendSheet> {
  List<CommunityPerson> _found = const [];
  String _q = '';
  String? _note;

  Future<void> _search(String raw) async {
    final q = normalizeHandle(raw);
    setState(() => _q = q);
    if (q.length < 2) {
      setState(() => _found = const []);
      return;
    }
    final r = await ref.read(communityApiProvider).search(q);
    if (!mounted || q != _q) return;
    setState(() => _found = r.when(ok: (p) => p, err: (_) => const []));
  }

  Future<void> _add(String handle) async {
    final r = await ref.read(communityApiProvider).addFriend(handle);
    if (!mounted) return;
    refreshCommunity(ref);
    setState(
      () => _note = r.when(
        ok: (s) => s == 'friends'
            ? 'You and @$handle are friends.'
            : 'Request sent to @$handle.',
        err: (f) => f.message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: Padding(
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a friend', style: t.titleLarge),
            const SizedBox(height: FitSpacing.sm),
            TextField(
              key: const ValueKey('community.add.search'),
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(
                prefixText: '@',
                hintText: 'Their handle',
              ),
              onChanged: _search,
            ),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.only(top: FitSpacing.sm),
                child: Text(_note!, key: const ValueKey('community.add.note')),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final p in _found)
                    ListTile(
                      key: ValueKey('community.found.${p.handle}'),
                      leading: ProfileAvatar(
                        avatarId: p.avatarId,
                        name: p.handle,
                        premium: false,
                        size: 34,
                      ),
                      title: Text('@${p.handle} ${flagOf(p.country)}'),
                      trailing: TextButton(
                        key: ValueKey('community.add.${p.handle}'),
                        onPressed: () => _add(p.handle),
                        child: const Text('Add'),
                      ),
                    ),
                  if (_found.isEmpty && _q.length >= 3)
                    Padding(
                      padding: const EdgeInsets.only(top: FitSpacing.md),
                      child: Text(
                        'No one with a handle starting @$_q.',
                        style: t.bodyMedium?.copyWith(color: FitColors.ink60),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          Text(
            'A club is any group: your hostel, your gym, your running crew, '
            'anywhere in the world. Share its code to let people in.',
            style: t.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.md),
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
                      'No clubs yet.',
                      key: const ValueKey('community.clubs.empty'),
                      style: t.bodyMedium,
                    ),
                  ]
                : [
                    for (final c in list) ...[
                      FitBlock(
                        key: ValueKey('community.club.${c.id}'),
                        padding: const EdgeInsets.all(FitSpacing.md),
                        onTap: () =>
                            context.push(Routes.communityClub(c.id), extra: c),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name, style: t.titleMedium),
                                  Text(
                                    '${c.members} ${c.members == 1 ? 'member' : 'members'} · code ${c.shownCode}${c.mine ? ' · yours' : ''}',
                                    style: t.bodySmall
                                        ?.copyWith(color: FitColors.ink60),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                      const SizedBox(height: FitSpacing.sm),
                    ],
                  ],
          ),
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

/* ---------------------------------------------------------------- world -- */

class _WorldView extends ConsumerWidget {
  const _WorldView({required this.profile});

  final CommunityProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final metric = ref.watch(boardMetricProvider);
    final countryOnly =
        ref.watch(worldCountryOnlyProvider) && profile.country != null;
    final country = countryOnly ? profile.country : null;
    return RefreshIndicator(
      onRefresh: () async => refreshCommunity(ref),
      child: ListView(
        key: const ValueKey('community.world'),
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          FitSpacing.sm,
          FitSpacing.screen,
          112,
        ),
        children: [
          if (!profile.onWorld) ...[
            FitBlock(
              key: const ValueKey('community.world.off'),
              padding: const EdgeInsets.all(FitSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You are not on the world board', style: t.titleMedium),
                  const SizedBox(height: FitSpacing.xs),
                  Text(
                    'You can see it; others see your handle, country and '
                    'counts here only if you choose to.',
                    style: t.bodyMedium,
                  ),
                  const SizedBox(height: FitSpacing.sm),
                  FilledButton(
                    key: const ValueKey('community.world.join'),
                    onPressed: () async {
                      await ref
                          .read(communityApiProvider)
                          .update(onWorld: true);
                      refreshCommunity(ref);
                    },
                    child: const Text('Show me on it'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FitSpacing.md),
          ],
          const BoardMetricPicker(),
          if (profile.country != null) ...[
            const SizedBox(height: FitSpacing.sm),
            SegmentedButton<bool>(
              key: const ValueKey('community.world.scope'),
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(
                  value: false,
                  label: Text(
                    'Everywhere',
                    key: ValueKey('community.world.everywhere'),
                  ),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    '${flagOf(profile.country)} ${kCountries[profile.country] ?? profile.country}',
                    key: const ValueKey('community.world.country'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              selected: {countryOnly},
              onSelectionChanged: (v) =>
                  ref.read(worldCountryOnlyProvider.notifier).set(v.first),
            ),
          ],
          const SizedBox(height: FitSpacing.md),
          BoardLoader(
            board: ref.watch(worldBoardProvider((metric, country))),
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
