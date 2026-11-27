import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/routing/navigation.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../premium/presentation/profile_avatar.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'invite_qr.dart';

/// Beta 6.7 (R1, owner 2026-11-27): the people side of Community, behind
/// the icon by the tabs: requests, your friends, people you may know, the
/// ones waiting, and your invite. The boards live in their own tab now.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final lists = ref.watch(friendListsProvider);
    final api = ref.read(communityApiProvider);
    final handle = ref.watch(communityMeProvider).value?.profile?.handle;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: const Text('People'),
        actions: [
          IconButton(
            key: const ValueKey('community.addFriend'),
            tooltip: 'Add a friend',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () => addFriend(context, ref),
          ),
        ],
      ),
      body: FitBackdrop(
        child: RefreshIndicator(
          onRefresh: () async => refreshCommunity(ref),
          child: ListView(
            key: const ValueKey('community.people'),
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: [
              ...lists.when(
                loading: () => const [
                  Padding(
                    padding: EdgeInsets.all(FitSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (_, __) => [
                  Text(
                    'Your friends are unavailable right now. Pull to try again.',
                    style: t.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                ],
                data: (l) => [
                  if (l.incoming.isNotEmpty) ...[
                    Text('FRIEND REQUESTS', style: t.labelSmall),
                    const SizedBox(height: FitSpacing.sm),
                    FitBlock(
                      child: Column(
                        children: [
                          for (final (i, p) in l.incoming.indexed) ...[
                            if (i > 0) const FitRule(),
                            ListTile(
                              key: ValueKey('community.incoming.${p.handle}'),
                              leading: _avatar(p),
                              title: Text('@${p.handle} ${flagOf(p.country)}'),
                              onTap: () => context.push(
                                Routes.communityPerson(p.userId),
                                extra: p.handle,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: ValueKey(
                                      'community.decline.${p.handle}',
                                    ),
                                    tooltip: 'Decline',
                                    icon: const Icon(Icons.close),
                                    onPressed: () async {
                                      await api.unfriend(p.userId);
                                      refreshCommunity(ref);
                                    },
                                  ),
                                  IconButton.filled(
                                    key: ValueKey(
                                      'community.accept.${p.handle}',
                                    ),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: FitSpacing.lg),
                  ],
                  Text(
                    l.friends.isEmpty
                        ? 'FRIENDS'
                        : 'FRIENDS · ${l.friends.length}',
                    style: t.labelSmall,
                  ),
                  const SizedBox(height: FitSpacing.sm),
                  if (l.friends.isEmpty)
                    Text(
                      'No friends yet. Add someone by their handle, or send '
                      'your invite below.',
                      key: const ValueKey('community.friends.empty'),
                      style: t.bodyMedium?.copyWith(color: FitColors.ink60),
                    )
                  else
                    FitBlock(
                      child: Column(
                        children: [
                          for (final (i, p) in l.friends.indexed) ...[
                            if (i > 0) const FitRule(),
                            ListTile(
                              key: ValueKey('community.friend.${p.handle}'),
                              leading: _avatar(p),
                              title: Text('@${p.handle} ${flagOf(p.country)}'),
                              trailing: const Icon(Icons.chevron_right),
                              // Beta 6.2 (C4): a friend's week.
                              onTap: () => context.push(
                                Routes.communityPerson(p.userId),
                                extra: p.handle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  // Beta 6.3 (C16, owner Q3): a count or a club, never which
                  // friends.
                  const _Suggestions(),
                  if (l.outgoing.isNotEmpty) ...[
                    const SizedBox(height: FitSpacing.lg),
                    Text('WAITING FOR AN ANSWER', style: t.labelSmall),
                    for (final p in l.outgoing)
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
                ],
              ),
              const SizedBox(height: FitSpacing.lg),
              _InviteLine(handle: handle),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _avatar(CommunityPerson p) => ProfileAvatar(
      avatarId: p.avatarId,
      name: p.handle,
      premium: false,
      size: 34,
    );

void _peopleSnack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Beta 6.3 (C16): friends of friends and club-mates, five at a time.
class _Suggestions extends ConsumerWidget {
  const _Suggestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final items = ref.watch(suggestionsProvider).value ?? const <Suggestion>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final api = ref.read(communityApiProvider);
    return Column(
      key: const ValueKey('community.suggestions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: FitSpacing.lg),
        Text('PEOPLE YOU MAY KNOW', style: t.labelSmall),
        const SizedBox(height: FitSpacing.sm),
        FitBlock(
          child: Column(
            children: [
              for (final (i, s) in items.take(5).indexed) ...[
                if (i > 0) const FitRule(),
                ListTile(
                  key: ValueKey('community.suggestion.${s.person.handle}'),
                  leading: ProfileAvatar(
                    avatarId: s.person.avatarId,
                    name: s.person.handle,
                    premium: false,
                    size: 34,
                  ),
                  title:
                      Text('@${s.person.handle} ${flagOf(s.person.country)}'),
                  subtitle: Text(s.why),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey(
                          'community.suggestion.hide.${s.person.handle}',
                        ),
                        tooltip: 'Not now',
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await api.dismissSuggestion(s.person.userId);
                          ref.invalidate(suggestionsProvider);
                        },
                      ),
                      IconButton(
                        key: ValueKey(
                          'community.suggestion.add.${s.person.handle}',
                        ),
                        tooltip: 'Add friend',
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          final r = await api.addFriend(s.person.handle);
                          refreshCommunity(ref);
                          if (context.mounted) {
                            _peopleSnack(
                              context,
                              r.when(
                                ok: (v) => v == 'friends'
                                    ? 'You are now friends.'
                                    : 'Request sent.',
                                err: (f) => f.message,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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

/// Find someone by their handle and send a request.
Future<void> addFriend(BuildContext context, WidgetRef ref) =>
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
