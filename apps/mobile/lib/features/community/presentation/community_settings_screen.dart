import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/fit_glass.dart';
import '../domain/community.dart';
import 'community_providers.dart';
import 'community_screen.dart';
import 'invite_qr.dart';

/// Beta 5.8 (ADR-057): the handle, the country, the world-board choice,
/// people blocked, and leaving Community. Beta 6.3: what friends see in the
/// feed (nothing until chosen), suggestions and notifications.
class CommunitySettingsScreen extends ConsumerWidget {
  const CommunitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final p = ref.watch(communityMeProvider).value?.profile;
    final blocked =
        ref.watch(blockedProvider).value ?? const <CommunityPerson>[];
    final api = ref.read(communityApiProvider);

    Future<void> save(Future<Object?> Function() run) async {
      await run();
      refreshCommunity(ref);
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: const Text('Community settings'),
      ),
      body: FitBackdrop(
        child: p == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                key: const ValueKey('communitySettings.list'),
                padding: const EdgeInsets.all(FitSpacing.screen),
                children: [
                  FitGroup(
                    label: 'You in Community',
                    children: [
                      FitRow(
                        key: const ValueKey('communitySettings.handle'),
                        icon: Icons.person_outline,
                        title: 'Handle',
                        value: '@${p.handle}',
                        onTap: () => _rename(context, ref, p.handle),
                      ),
                      // Beta 6.2 (C15): a friend's camera opens FITOS on "Add @you?".
                      FitRow(
                        key: const ValueKey('communitySettings.qr'),
                        icon: Icons.qr_code_2,
                        title: 'My QR code',
                        value: 'For friends to scan',
                        onTap: () => showHandleQr(context, p.handle),
                      ),
                      FitRow(
                        key: const ValueKey('communitySettings.country'),
                        icon: Icons.flag_outlined,
                        title: 'Country',
                        value: p.country == null
                            ? 'Not shown'
                            : '${flagOf(p.country)} ${kCountries[p.country] ?? p.country}',
                        onTap: () async {
                          final c =
                              await pickCountry(context, current: p.country);
                          if (c == null) return;
                          await save(
                            () => c.isEmpty
                                ? api.update(clearCountry: true)
                                : api.update(country: c),
                          );
                        },
                      ),
                      FitRow(
                        key: const ValueKey('communitySettings.world'),
                        icon: Icons.public,
                        title: 'Show me on the world board',
                        trailing: Switch(
                          key: const ValueKey('communitySettings.worldSwitch'),
                          value: p.onWorld,
                          onChanged: (v) => save(() => api.update(onWorld: v)),
                        ),
                        onTap: () =>
                            save(() => api.update(onWorld: !p.onWorld)),
                      ),
                    ],
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  // Beta 6.3 (C1, owner Q1): each kind on its own; none at first.
                  FitGroup(
                    label: 'Share with friends',
                    children: [
                      for (final k in FeedKind.values)
                        FitRow(
                          key: ValueKey('communitySettings.feed.${k.wire}'),
                          icon: switch (k) {
                            FeedKind.session => Icons.fitness_center,
                            FeedKind.run => Icons.directions_run,
                            FeedKind.record => Icons.emoji_events_outlined,
                            FeedKind.streak =>
                              Icons.local_fire_department_outlined,
                          },
                          title: k.label,
                          value: k.hint,
                          trailing: Switch(
                            key: ValueKey(
                              'communitySettings.feedSwitch.${k.wire}',
                            ),
                            value: p.feed.contains(k),
                            onChanged: (v) => save(
                              () => api.update(
                                feed: v
                                    ? {...p.feed, k}
                                    : ({...p.feed}..remove(k)),
                              ),
                            ),
                          ),
                          onTap: () => save(
                            () => api.update(
                              feed: p.feed.contains(k)
                                  ? ({...p.feed}..remove(k))
                                  : {...p.feed, k},
                            ),
                          ),
                        ),
                      FitRow(
                        key: const ValueKey('communitySettings.suggest'),
                        icon: Icons.group_add_outlined,
                        title: 'Suggest me to friends of friends',
                        value: 'And to people in my clubs',
                        trailing: Switch(
                          key:
                              const ValueKey('communitySettings.suggestSwitch'),
                          value: p.suggest,
                          onChanged: (v) => save(() => api.update(suggest: v)),
                        ),
                        onTap: () =>
                            save(() => api.update(suggest: !p.suggest)),
                      ),
                      FitRow(
                        key: const ValueKey('communitySettings.notify'),
                        icon: Icons.notifications_none,
                        title: 'Cheers and nudges',
                        value: 'One evening note a day, and nudges',
                        trailing: Switch(
                          key: const ValueKey('communitySettings.notifySwitch'),
                          value: p.notify,
                          onChanged: (v) => save(() => api.update(notify: v)),
                        ),
                        onTap: () => save(() => api.update(notify: !p.notify)),
                      ),
                    ],
                  ),
                  const SizedBox(height: FitSpacing.sm),
                  Text(
                    'Only friends see your posts, and only the kinds you turn '
                    'on, from then on. Never weights, food, body or where you '
                    'ran. Turning a kind off deletes its posts.',
                    style: t.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  FitGroup(
                    label: 'Blocked',
                    children: [
                      if (blocked.isEmpty)
                        const FitRow(
                          icon: Icons.visibility_off_outlined,
                          title: 'Nobody',
                        ),
                      for (final b in blocked)
                        FitRow(
                          key:
                              ValueKey('communitySettings.blocked.${b.handle}'),
                          icon: Icons.visibility_off_outlined,
                          title: '@${b.handle}',
                          trailing: TextButton(
                            key: ValueKey(
                              'communitySettings.unblock.${b.handle}',
                            ),
                            onPressed: () => save(() => api.unblock(b.userId)),
                            child: const Text('Unblock'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: FitSpacing.lg),
                  FitGroup(
                    children: [
                      FitRow(
                        key: const ValueKey('communitySettings.leave'),
                        icon: Icons.logout,
                        title: 'Leave Community',
                        destructive: true,
                        onTap: () => _leave(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: FitSpacing.sm),
                  Text(
                    'Leaving takes you off every board and friends list at once, '
                    'and ends your clubs (one you made passes to its longest '
                    'member). People you blocked stay blocked.',
                    style: t.bodySmall?.copyWith(color: FitColors.ink60),
                  ),
                ],
              ),
      ),
    );
  }
}

Future<void> _rename(
  BuildContext context,
  WidgetRef ref,
  String current,
) async {
  final value = await askText(
    context,
    title: 'Your handle',
    fieldKey: const ValueKey('communitySettings.handle.field'),
    okKey: const ValueKey('communitySettings.handle.save'),
    ok: 'Save',
    initial: current,
    prefix: '@',
    maxLength: 21,
  );
  if (value == null) return;
  final handle = normalizeHandle(value);
  if (handle == current) return;
  final r = await ref.read(communityApiProvider).update(handle: handle);
  if (!context.mounted) return;
  refreshCommunity(ref);
  r.when(
    ok: (_) {},
    err: (f) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          f is Conflict ? 'That handle is taken.' : f.message,
        ),
      ),
    ),
  );
}

Future<void> _leave(BuildContext context, WidgetRef ref) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Leave Community?'),
      content: const Text(
        'You come off every board and friends list now. You can join again '
        'later, with no friends or clubs.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(d).pop(false),
          child: const Text('Stay'),
        ),
        FilledButton(
          key: const ValueKey('communitySettings.leave.confirm'),
          onPressed: () => Navigator.of(d).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  if (sure != true) return;
  await ref.read(communityApiProvider).leave();
  refreshCommunity(ref);
  if (context.mounted) context.popOrHome();
}
