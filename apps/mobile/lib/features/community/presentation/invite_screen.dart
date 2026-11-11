import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/navigation.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/community.dart';
import 'community_providers.dart';

/// Beta 6.2 (C8, C15, owner Q1): a tryfitos.me club or friend link opened
/// FITOS. Nothing happens until the person taps: join this club, or ask
/// this person to be friends.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({required this.invite, super.key});

  final InviteLink invite;

  @override
  ConsumerState<InviteScreen> createState() => _InviteState();
}

class _InviteState extends ConsumerState<InviteScreen> {
  bool _busy = false;
  String? _note;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _note = null;
    });
    final api = ref.read(communityApiProvider);
    switch (widget.invite) {
      case ClubInvite(:final code):
        final r = await api.joinClub(code);
        if (!mounted) return;
        refreshCommunity(ref);
        r.when(
          ok: (c) =>
              context.pushReplacement(Routes.communityClub(c.id), extra: c),
          err: (f) => setState(() => _note = f.message),
        );
      case FriendInvite(:final handle):
        final r = await api.addFriend(handle);
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
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = ref.watch(communityMeProvider);
    final joined = me.value?.joined;
    final (title, what, action) = switch (widget.invite) {
      ClubInvite(:final code) => (
          'Join a club',
          'Code ${code.substring(0, 4)}-${code.substring(4)}',
          'Join the club',
        ),
      FriendInvite(:final handle) => (
          'Add a friend',
          '@$handle',
          'Ask to be friends',
        ),
    };
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text(title),
      ),
      body: FitBackdrop(
        child: ListView(
          key: const ValueKey('invite.list'),
          padding: const EdgeInsets.all(FitSpacing.screen),
          children: [
            Text(
              what,
              key: const ValueKey('invite.what'),
              style: t.headlineSmall,
            ),
            const SizedBox(height: FitSpacing.md),
            if (joined == false) ...[
              Text(
                'Join Community first: choose a handle, then open the link again.',
                style: t.bodyMedium,
              ),
              const SizedBox(height: FitSpacing.md),
              FilledButton(
                key: const ValueKey('invite.community'),
                onPressed: () => context.go(Routes.community),
                child: const Text('Open Community'),
              ),
            ] else
              FilledButton(
                key: const ValueKey('invite.go'),
                onPressed: _busy || joined == null ? null : _go,
                child: Text(action),
              ),
            if (_note != null) ...[
              const SizedBox(height: FitSpacing.md),
              Text(_note!, key: const ValueKey('invite.note')),
            ],
          ],
        ),
      ),
    );
  }
}
