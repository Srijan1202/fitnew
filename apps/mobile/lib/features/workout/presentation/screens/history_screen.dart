import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_providers.dart';
import '../widgets/rest_bar.dart';
import 'session_summary_screen.dart';

/// Completed (and abandoned) sessions, newest first, with more on scroll.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final List<SessionListItem> _more = [];
  String? _nextBefore;
  bool _loadingMore = false;
  bool _pagedOnce = false;

  Future<void> _loadMore() async {
    if (_loadingMore || _nextBefore == null) return;
    setState(() => _loadingMore = true);
    final result =
        await ref.read(workoutRepositoryProvider).history(before: _nextBefore);
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      result.when(
        ok: (page) {
          _more.addAll(page.items);
          _nextBefore = page.nextBefore;
        },
        err: (_) {},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text('HISTORY', style: textTheme.labelSmall),
        centerTitle: false,
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(FitSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Could not load your history',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: FitSpacing.sm),
                AuthFeedback.error(
                  (e is Failure ? e : const Unknown()).message,
                ),
                const SizedBox(height: FitSpacing.lg),
                FilledButton(
                  onPressed: () => ref.invalidate(historyProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          data: (first) {
            if (!_pagedOnce) {
              _pagedOnce = true;
              _nextBefore = first.nextBefore;
            }
            final items = [...first.items, ..._more];
            if (items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(FitSpacing.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('No sessions yet', style: textTheme.displaySmall),
                    const SizedBox(height: FitSpacing.sm),
                    Text(
                      'Your first logged session will show up here.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                  _loadMore();
                }
                return false;
              },
              child: ListView.separated(
                key: const ValueKey('history.list'),
                padding: const EdgeInsets.only(bottom: FitSpacing.xl),
                itemCount: items.length + (_nextBefore != null ? 1 : 0),
                separatorBuilder: (_, __) =>
                    const Divider(color: FitColors.rule, height: 1),
                itemBuilder: (context, i) {
                  if (i == items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(FitSpacing.md),
                      child: Center(
                        child: TextButton(
                          key: const ValueKey('history.more'),
                          onPressed: _loadingMore ? null : _loadMore,
                          child: const Text('Load more'),
                        ),
                      ),
                    );
                  }
                  return _Row(item: items[i]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});

  final SessionListItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final when = DateTime.parse(item.startedAt).toLocal();
    final date =
        '${when.day.toString().padLeft(2, '0')}.${when.month.toString().padLeft(2, '0')}.${when.year}';
    final abandoned = item.status == SessionStatus.abandoned;
    return InkWell(
      key: ValueKey('history.${item.id}'),
      onTap: () => context.push(Routes.historyDetail(item.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FitSpacing.screen,
          vertical: FitSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    style: textTheme.titleMedium?.copyWith(
                      color: abandoned ? FitColors.ink35 : FitColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    abandoned
                        ? '$date · discarded'
                        : '$date · ${item.workingSets} sets · ${item.durationSeconds == null ? '—' : formatClock(Duration(seconds: item.durationSeconds!))}'
                            '${item.prCount > 0 ? ' · ${item.prCount} PR' : ''}',
                    style: textTheme.bodyMedium?.copyWith(
                      color:
                          item.prCount > 0 ? FitColors.pine : FitColors.ink60,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: FitColors.ink60),
          ],
        ),
      ),
    );
  }
}

/// One past session, fetched from the server by id.
class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({required this.serverId, super.key});

  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(sessionDetailProvider(serverId));
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.popOrHome())),
      body: SafeArea(
        child: async.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(FitSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Could not load this session',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: FitSpacing.sm),
                AuthFeedback.error(
                  (e is Failure ? e : const Unknown()).message,
                ),
                const SizedBox(height: FitSpacing.lg),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(sessionDetailProvider(serverId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          data: (session) => SummaryBody(session: session),
        ),
      ),
    );
  }
}
