import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../../premium/presentation/profile_avatar.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'community_screen.dart';

/// Beta 6.2 (C5, audit S3): a club's owner renames it, makes a new code,
/// removes members (kept out until let back, owner Q2) and passes it on.
class ClubSettingsScreen extends ConsumerWidget {
  const ClubSettingsScreen({required this.clubId, super.key});

  final String clubId;

  /// The newest message replaces the one showing.
  void _say(BuildContext context, String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _sure(
    BuildContext context, {
    required String title,
    required String body,
    required String ok,
    required String okKey,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: ValueKey(okKey),
              onPressed: () => Navigator.of(d).pop(true),
              child: Text(ok),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final api = ref.read(communityApiProvider);
    final club = ref
        .watch(clubsProvider)
        .value
        ?.where((c) => c.id == clubId)
        .firstOrNull;
    final members = ref
            .watch(clubBoardProvider((clubId, BoardMetric.sessions)))
            .value
            ?.rows
            .where((r) => !r.me)
            .toList() ??
        const <BoardRow>[];
    final removed = ref.watch(removedFromClubProvider(clubId)).value ??
        const <CommunityPerson>[];
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: const Text('Club settings'),
      ),
      body: FitBackdrop(
        child: ListView(
          key: const ValueKey('clubSettings.list'),
          padding: const EdgeInsets.all(FitSpacing.screen),
          children: [
            FitBlock(
              child: Column(
                children: [
                  ListTile(
                    key: const ValueKey('clubSettings.rename'),
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Name'),
                    subtitle: Text(club?.name ?? ''),
                    onTap: () async {
                      final name = await askText(
                        context,
                        title: 'Rename the club',
                        fieldKey: const ValueKey('clubSettings.rename.field'),
                        okKey: const ValueKey('clubSettings.rename.ok'),
                        ok: 'Rename',
                        hint: club?.name ?? '',
                        maxLength: 40,
                        capitalization: TextCapitalization.words,
                      );
                      if (name == null || name.trim().isEmpty) return;
                      final r = await api.renameClub(clubId, name);
                      refreshCommunity(ref);
                      if (context.mounted) {
                        _say(
                          context,
                          r.when(ok: (_) => 'Renamed.', err: (f) => f.message),
                        );
                      }
                    },
                  ),
                  const FitRule(),
                  ListTile(
                    key: const ValueKey('clubSettings.code'),
                    leading: const Icon(Icons.autorenew),
                    title: const Text('Make a new code'),
                    subtitle: Text(
                      club == null
                          ? 'The old code and link stop working.'
                          : 'Now ${club.shownCode}. The old code and link stop working.',
                    ),
                    onTap: () async {
                      final sure = await _sure(
                        context,
                        title: 'Make a new code?',
                        body:
                            'Members stay in. Anyone who has the old code or link can no longer join with it.',
                        ok: 'New code',
                        okKey: 'clubSettings.code.ok',
                      );
                      if (!sure) return;
                      final r = await api.newClubCode(clubId);
                      refreshCommunity(ref);
                      if (context.mounted) {
                        _say(
                          context,
                          r.when(
                            ok: (c) => 'The new code is ${c.shownCode}.',
                            err: (f) => f.message,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: FitSpacing.lg),
            Text('MEMBERS', style: t.labelSmall),
            const SizedBox(height: FitSpacing.sm),
            if (members.isEmpty)
              Text(
                'Nobody else is in the club yet.',
                style: t.bodyMedium?.copyWith(color: FitColors.ink60),
              )
            else
              FitBlock(
                child: Column(
                  children: [
                    for (final (i, m) in members.indexed) ...[
                      if (i > 0) const FitRule(),
                      ListTile(
                        key: ValueKey('clubSettings.member.${m.handle}'),
                        leading: ProfileAvatar(
                          avatarId: m.avatarId,
                          name: m.handle,
                          premium: false,
                          size: 34,
                        ),
                        title: Text('@${m.handle} ${flagOf(m.country)}'),
                        trailing: PopupMenuButton<String>(
                          key: ValueKey('clubSettings.member.${m.handle}.menu'),
                          onSelected: (v) async {
                            if (v == 'remove') {
                              final sure = await _sure(
                                context,
                                title: 'Remove @${m.handle}?',
                                body:
                                    'They leave the club and cannot join again with the code until you let them back.',
                                ok: 'Remove',
                                okKey: 'clubSettings.remove.ok',
                              );
                              if (!sure) return;
                              final r =
                                  await api.removeMember(clubId, m.userId);
                              refreshCommunity(ref);
                              if (context.mounted) {
                                _say(
                                  context,
                                  r.when(
                                    ok: (_) => '@${m.handle} was removed.',
                                    err: (f) => f.message,
                                  ),
                                );
                              }
                            } else if (v == 'owner') {
                              final sure = await _sure(
                                context,
                                title: 'Make @${m.handle} the owner?',
                                body:
                                    'They run the club from now on; you stay in it as a member.',
                                ok: 'Make owner',
                                okKey: 'clubSettings.owner.ok',
                              );
                              if (!sure) return;
                              final r = await api.passClub(clubId, m.userId);
                              refreshCommunity(ref);
                              if (!context.mounted) return;
                              r.when(
                                ok: (_) => context.popOrHome(),
                                err: (f) => _say(context, f.message),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              key: ValueKey('clubSettings.owner.${m.handle}'),
                              value: 'owner',
                              child: const Text('Make owner'),
                            ),
                            PopupMenuItem(
                              key: ValueKey('clubSettings.remove.${m.handle}'),
                              value: 'remove',
                              child: const Text('Remove from the club'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (removed.isNotEmpty) ...[
              const SizedBox(height: FitSpacing.lg),
              Text('REMOVED', style: t.labelSmall),
              const SizedBox(height: FitSpacing.sm),
              FitBlock(
                child: Column(
                  children: [
                    for (final (i, p) in removed.indexed) ...[
                      if (i > 0) const FitRule(),
                      ListTile(
                        key: ValueKey('clubSettings.removed.${p.handle}'),
                        title: Text('@${p.handle}'),
                        subtitle: const Text('Cannot join with the code'),
                        trailing: TextButton(
                          key: ValueKey('clubSettings.letBack.${p.handle}'),
                          onPressed: () async {
                            await api.letBack(clubId, p.userId);
                            refreshCommunity(ref);
                          },
                          child: const Text('Let back'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
