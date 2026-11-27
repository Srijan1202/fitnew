import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../premium/presentation/profile_avatar.dart';
import '../domain/community.dart';
import 'community_providers.dart';

/// Beta 6.3 (C1–C3, owner Q1, Q2): what friends shared, newest first, with a
/// cheer on each; nudges received at the top; a card to start sharing while
/// nothing is. Beta 6.5 (K1): a club's feed too, with [clubId]: what its
/// members share, from after they joined (no nudges there).
class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key, this.now, this.clubId});

  /// For tests: the clock the "3 h ago" lines read.
  final DateTime Function()? now;

  /// A club's feed; null for friends'.
  final String? clubId;

  @override
  ConsumerState<FeedView> createState() => _FeedState();
}

class _FeedState extends ConsumerState<FeedView> {
  /// Older pages, and cheers given here, on top of the first page.
  final List<FeedPost> _older = [];
  final Map<String, FeedPost> _changed = {};
  DateTime? _next;
  bool _loadingMore = false;
  Feed? _first;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  String? get _club => widget.clubId;

  void _reload() => _club == null
      ? ref.invalidate(feedProvider)
      : ref.invalidate(clubFeedProvider(_club!));

  Future<void> _more() async {
    final before = _next;
    if (before == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    final api = ref.read(communityApiProvider);
    final r = _club == null
        ? await api.feed(before: before)
        : await api.clubFeed(_club!, before: before);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      r.when(
        ok: (f) {
          _older.addAll(f.items);
          _next = f.next;
        },
        err: (_) {},
      );
    });
  }

  Future<void> _cheer(FeedPost p) async {
    final on = !p.cheered;
    // At once on screen; the server's count when it answers.
    setState(
      () => _changed[p.id] = p.cheer(on: on, kudos: p.kudos + (on ? 1 : -1)),
    );
    final r = await ref.read(communityApiProvider).cheer(p.id, on: on);
    if (!mounted) return;
    setState(
      () => r.when(
        ok: (k) => _changed[p.id] = p.cheer(on: k.cheered, kudos: k.kudos),
        err: (_) => _changed[p.id] = p,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final club = _club;
    final feed = ref.watch(
      club == null ? feedProvider : clubFeedProvider(club),
    );
    final profile = ref.watch(communityMeProvider).value?.profile;
    // A fresh first page: older pages and cheers given here start again.
    final first = feed.value;
    if (first != null && !identical(first, _first)) {
      _first = first;
      _older.clear();
      _changed.clear();
      _next = first.next;
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(FitSpacing.screen),
          children: [
            Text(
              e is Offline
                  ? 'The feed needs a connection.'
                  : 'The feed is unavailable right now.',
              key: const ValueKey('feed.problem'),
            ),
            TextButton(
              onPressed: _reload,
              child: const Text('Try again'),
            ),
          ],
        ),
        data: (f) {
          final posts = [
            for (final p in [...f.items, ..._older]) _changed[p.id] ?? p,
          ];
          return ListView(
            key: ValueKey(club == null ? 'feed.list' : 'clubFeed.list'),
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              112,
            ),
            children: [
              if (f.nudges.isNotEmpty) ...[
                _Nudges(nudges: f.nudges),
                const SizedBox(height: FitSpacing.lg),
              ],
              if (profile != null && profile.feed.isEmpty) ...[
                const _StartSharing(),
                const SizedBox(height: FitSpacing.lg),
              ],
              if (posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
                  child: Text(
                    club == null
                        ? 'Nothing here yet. When friends share their sessions, '
                            'runs and records, they show here.'
                        : 'Nothing here yet. When members share their '
                            'sessions, runs and records, they show here.',
                    key: const ValueKey('feed.empty'),
                    style: t.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                )
              else
                // Beta 6.7 (R4): posts under Today, Yesterday or the date.
                for (final (gi, g) in feedDays(posts, _now).indexed) ...[
                  if (gi > 0) const SizedBox(height: FitSpacing.lg),
                  Text(
                    g.label.toUpperCase(),
                    key: ValueKey('feed.day.$gi'),
                    style: t.labelSmall,
                  ),
                  const SizedBox(height: FitSpacing.sm),
                  FitBlock(
                    child: Column(
                      children: [
                        for (final (i, p) in g.posts.indexed) ...[
                          if (i > 0) const FitRule(),
                          _PostTile(
                            post: p,
                            now: _now,
                            onCheer: p.mine ? null : () => _cheer(p),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              if (_next != null) ...[
                const SizedBox(height: FitSpacing.sm),
                Center(
                  child: TextButton(
                    key: const ValueKey('feed.more'),
                    onPressed: _loadingMore ? null : _more,
                    child: Text(_loadingMore ? 'Loading…' : 'Older posts'),
                  ),
                ),
              ],
              const SizedBox(height: FitSpacing.lg),
              Text(
                club == null
                    ? 'Friends see only what each person shares: never weights, '
                        'food, body or where they ran. Posts go after 30 days.'
                    : 'Members see only what each person shares, from after '
                        'they joined: never weights, food, body or where they '
                        'ran. Posts go after 30 days.',
                style: t.bodySmall?.copyWith(color: FitColors.ink60),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Nudges extends StatelessWidget {
  const _Nudges({required this.nudges});

  final List<Nudge> nudges;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final names = nudges.map((n) => '@${n.person.handle}').toList();
    final who = names.length <= 2
        ? names.join(' and ')
        : '${names.first} and ${names.length - 1} others';
    return FitBlock(
      key: const ValueKey('feed.nudges'),
      padding: const EdgeInsets.all(FitSpacing.md),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: FitColors.accent),
          const SizedBox(width: FitSpacing.md),
          Expanded(
            child: Text(
              '$who nudged you: time to move. A short session counts.',
              style: t.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartSharing extends StatelessWidget {
  const _StartSharing();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FitBlock(
      key: const ValueKey('feed.start'),
      padding: const EdgeInsets.all(FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share with friends and clubs', style: t.titleMedium),
          const SizedBox(height: FitSpacing.xs),
          // Beta 6.5 (K0): sharing is on from joining; this shows only to
          // someone who turned every kind off.
          Text(
            'You turned sharing off, so nothing of yours is in the feed. '
            'Choose what friends and your clubs see: sessions you finish, '
            'runs, records or streak milestones.',
            style: t.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.sm),
          FilledButton.tonal(
            key: const ValueKey('feed.start.choose'),
            onPressed: () => context.push(Routes.communitySettings),
            child: const Text('Choose what to share'),
          ),
        ],
      ),
    );
  }
}

/// Beta 6.7 (R4): the feed's posts by the day they happened, newest first.
List<({String label, List<FeedPost> posts})> feedDays(
  List<FeedPost> posts,
  DateTime now,
) {
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
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final n = now.toLocal();
  final today = DateTime(n.year, n.month, n.day);
  String label(DateTime at) {
    final l = at.toLocal();
    final d = DateTime(l.year, l.month, l.day);
    final back = today.difference(d).inDays;
    if (back <= 0) return 'Today';
    if (back == 1) return 'Yesterday';
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  final out = <({String label, List<FeedPost> posts})>[];
  for (final p in posts) {
    final l = label(p.at);
    if (out.isNotEmpty && out.last.label == l) {
      out.last.posts.add(p);
    } else {
      out.add((label: l, posts: [p]));
    }
  }
  return out;
}

/// Beta 6.7 (R4): what kind of post, as a small mark on the avatar.
IconData postIcon(PostKind kind) => switch (kind) {
      PostKind.session => Icons.fitness_center,
      PostKind.run => Icons.directions_run,
      PostKind.liftRecord || PostKind.runRecord => Icons.emoji_events,
      PostKind.streak => Icons.local_fire_department,
    };

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.now, this.onCheer});

  final FeedPost post;
  final DateTime now;

  /// Null on your own posts.
  final VoidCallback? onCheer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = post;
    final by = p.mine ? cheeredLine(p) : null;
    return Padding(
      key: ValueKey('feed.post.${p.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: FitSpacing.md,
        vertical: FitSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ProfileAvatar(
                avatarId: p.person.avatarId,
                name: p.person.handle,
                premium: false,
                size: 36,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  key: ValueKey('feed.kind.${p.id}.${p.kind.wire}'),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: FitColors.paper2,
                    shape: BoxShape.circle,
                    border: Border.all(color: FitColors.rule),
                  ),
                  child: Icon(
                    postIcon(p.kind),
                    size: 12,
                    color: p.kind == PostKind.liftRecord ||
                            p.kind == PostKind.runRecord
                        ? FitColors.amber
                        : FitColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: FitSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: p.mine ? 'You' : '@${p.person.handle}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: ' ${postLine(p)}'),
                    ],
                  ),
                  key: ValueKey('feed.line.${p.id}'),
                  style: t.bodyLarge,
                ),
                Text(
                  [agoOf(p.at, now), if (by != null) by].join(' · '),
                  key: ValueKey('feed.meta.${p.id}'),
                  style: t.bodySmall?.copyWith(color: FitColors.ink60),
                ),
              ],
            ),
          ),
          // Beta 6.7 (R4): always a heart and its count, in a column of
          // its own width, so lines don't jump between posts.
          SizedBox(
            width: 56,
            child: onCheer != null
                ? TextButton.icon(
                    key: ValueKey('feed.cheer.${p.id}'),
                    onPressed: onCheer,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor:
                          p.cheered ? FitColors.accent : FitColors.ink60,
                    ),
                    icon: Icon(
                      p.cheered ? Icons.favorite : Icons.favorite_border,
                      color: p.cheered ? FitColors.accent : FitColors.ink60,
                      semanticLabel: p.cheered ? 'Cheered' : 'Cheer',
                    ),
                    label: Text(p.kudos > 0 ? '${p.kudos}' : ''),
                  )
                : p.kudos > 0
                    ? Padding(
                        padding: const EdgeInsets.only(top: FitSpacing.sm),
                        child: Row(
                          key: ValueKey('feed.kudos.${p.id}'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 18,
                              color: FitColors.accent,
                            ),
                            const SizedBox(width: FitSpacing.xs),
                            Text('${p.kudos}', style: t.labelLarge),
                          ],
                        ),
                      )
                    : null,
          ),
        ],
      ),
    );
  }
}
