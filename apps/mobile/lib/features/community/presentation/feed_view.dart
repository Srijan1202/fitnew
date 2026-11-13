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
/// nothing is.
class FeedView extends ConsumerStatefulWidget {
  const FeedView({super.key, this.now});

  /// For tests: the clock the "3 h ago" lines read.
  final DateTime Function()? now;

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

  Future<void> _more() async {
    final before = _next;
    if (before == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    final r = await ref.read(communityApiProvider).feed(before: before);
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
    final feed = ref.watch(feedProvider);
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
      onRefresh: () async => ref.invalidate(feedProvider),
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
              onPressed: () => ref.invalidate(feedProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
        data: (f) {
          final posts = [
            for (final p in [...f.items, ..._older]) _changed[p.id] ?? p,
          ];
          return ListView(
            key: const ValueKey('feed.list'),
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
                    'Nothing here yet. When friends share their sessions, '
                    'runs and records, they show here.',
                    key: const ValueKey('feed.empty'),
                    style: t.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                )
              else
                FitBlock(
                  child: Column(
                    children: [
                      for (final (i, p) in posts.indexed) ...[
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
                'Friends see only what each person shares: never weights, '
                'food, body or where they ran. Posts go after 30 days.',
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
          Icon(Icons.waving_hand_outlined, color: FitColors.accent),
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
          Text('Share with your friends', style: t.titleMedium),
          const SizedBox(height: FitSpacing.xs),
          Text(
            'Nothing of yours is in the feed. Choose what friends see: '
            'sessions you finish, runs, records or streak milestones.',
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
          ProfileAvatar(
            avatarId: p.person.avatarId,
            name: p.person.handle,
            premium: false,
            size: 36,
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
          if (onCheer != null)
            TextButton.icon(
              key: ValueKey('feed.cheer.${p.id}'),
              onPressed: onCheer,
              icon: Icon(
                p.cheered ? Icons.favorite : Icons.favorite_border,
                color: p.cheered ? FitColors.accent : FitColors.ink60,
              ),
              label: Text(p.kudos > 0 ? '${p.kudos}' : 'Cheer'),
            )
          else if (p.kudos > 0)
            Padding(
              padding: const EdgeInsets.only(top: FitSpacing.xs),
              child: Row(
                key: ValueKey('feed.kudos.${p.id}'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, size: 18, color: FitColors.accent),
                  const SizedBox(width: FitSpacing.xs),
                  Text('${p.kudos}', style: t.labelLarge),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
