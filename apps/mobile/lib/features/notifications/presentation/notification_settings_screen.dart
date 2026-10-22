import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/routing/navigation.dart';
import '../../../core/theme/tokens.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../domain/notifications.dart';
import 'notification_coordinator.dart';

/// Phase 15 (§21, ADR-021): every reminder switchable, the tone, quiet
/// hours, what is coming up and why, and a sample to see the words.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotifySettings? _settings;
  Failure? _failure;
  bool _saving = false;
  String? _sample;

  Future<void> _update(
    Map<String, dynamic> patch,
    NotifySettings optimistic,
  ) async {
    final before = _settings;
    setState(() {
      _settings = optimistic;
      _saving = true;
      _failure = null;
    });
    final r = await ref.read(notificationsApiProvider).update(patch);
    if (!mounted) return;
    switch (r) {
      case Ok(:final value):
        setState(() {
          _settings = value;
          _saving = false;
        });
        ref.invalidate(notifySettingsProvider);
        await ref.read(notificationCoordinatorProvider.notifier).refresh();
      case Err(:final failure):
        setState(() {
          _settings = before;
          _saving = false;
          _failure = failure;
        });
    }
  }

  NotifySettings _with(
    NotifySettings s, {
    bool? enabled,
    NotifyTone? tone,
    Map<NotifyKind, bool>? kinds,
    String? quietStart,
    String? quietEnd,
  }) =>
      NotifySettings(
        enabled: enabled ?? s.enabled,
        tone: tone ?? s.tone,
        kinds: kinds ?? s.kinds,
        quietStart: quietStart ?? s.quietStart,
        quietEnd: quietEnd ?? s.quietEnd,
      );

  Future<void> _pickTime(NotifySettings s, {required bool start}) async {
    final current = start ? s.quietStart : s.quietEnd;
    final parts = current.split(':').map(int.parse).toList();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: parts[0], minute: parts[1]),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (picked == null) return;
    final v = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    await _update(
      {start ? 'quietStart' : 'quietEnd': v},
      start ? _with(s, quietStart: v) : _with(s, quietEnd: v),
    );
  }

  Future<void> _trySample(NotifySettings s) async {
    final kind = NotifyKind.values.firstWhere(
      (k) => s.kinds[k] ?? false,
      orElse: () => NotifyKind.workoutReminder,
    );
    final r = await ref.read(notificationsApiProvider).preview(kind);
    if (!mounted) return;
    switch (r) {
      case Ok(:final value):
        setState(() => _sample = '${value.title}\n${value.body}');
        await ref
            .read(notificationSchedulerProvider)
            .showNow(value.title, value.body);
      case Err(:final failure):
        setState(() => _failure = failure);
    }
  }

  String _when(DateTime at) {
    final local =
        tz.TZDateTime.from(at, userLocation(ref.read(userTimezoneProvider)));
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${days[local.weekday - 1]} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loaded = ref.watch(notifySettingsProvider);
    final notify = ref.watch(notificationCoordinatorProvider);
    final coordinator = ref.read(notificationCoordinatorProvider.notifier);
    final now = ref.read(notifyClockProvider)();
    final upcoming = notify.upcoming(now, coordinator.cancelled);
    final s = _settings ?? loaded.value;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        centerTitle: false,
        title: Text('NOTIFICATIONS', style: textTheme.labelSmall),
      ),
      body: SafeArea(
        top: false,
        child: s == null
            ? Center(
                child: loaded.hasError
                    ? Padding(
                        padding: const EdgeInsets.all(FitSpacing.screen),
                        child: Text(
                          (loaded.error is Failure
                                  ? loaded.error! as Failure
                                  : const Unknown())
                              .message,
                          key: const ValueKey('notify.loadError'),
                        ),
                      )
                    : const CircularProgressIndicator(),
              )
            : ListView(
                key: const ValueKey('notify.scroll'),
                padding: const EdgeInsets.fromLTRB(
                  FitSpacing.screen,
                  FitSpacing.sm,
                  FitSpacing.screen,
                  FitSpacing.xl,
                ),
                children: <Widget>[
                  if (notify.permitted == false)
                    _PermissionCard(
                      onAllow: () => coordinator.askPermission(),
                    ),
                  SwitchListTile(
                    key: const ValueKey('notify.enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: Text('Reminders', style: textTheme.titleMedium),
                    subtitle: const Text(
                      'At most two a day, three hours apart. FITOS learns when '
                      'you usually train and eat, and times them around that.',
                    ),
                    value: s.enabled,
                    onChanged: _saving
                        ? null
                        : (v) => _update({'enabled': v}, _with(s, enabled: v)),
                  ),
                  if (_failure case final f?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FitSpacing.sm),
                      child: Text(
                        f.message,
                        key: const ValueKey('notify.error'),
                        style: textTheme.bodyMedium
                            ?.copyWith(color: FitColors.oxide),
                      ),
                    ),
                  if (s.enabled) ...<Widget>[
                    const SizedBox(height: FitSpacing.md),
                    Text('TONE', style: textTheme.labelSmall),
                    const SizedBox(height: FitSpacing.xs),
                    Row(
                      children: <Widget>[
                        for (final t in NotifyTone.values) ...<Widget>[
                          Expanded(
                            child: ChoiceChip(
                              key: ValueKey('notify.tone.${t.wire}'),
                              shape: const RoundedRectangleBorder(),
                              showCheckmark: false,
                              label: SizedBox(
                                width: double.infinity,
                                child:
                                    Text(t.label, textAlign: TextAlign.center),
                              ),
                              selected: s.tone == t,
                              onSelected: _saving
                                  ? null
                                  : (_) => _update(
                                        {'tone': t.wire},
                                        _with(s, tone: t),
                                      ),
                            ),
                          ),
                          if (t != NotifyTone.values.last)
                            const SizedBox(width: FitSpacing.sm),
                        ],
                      ],
                    ),
                    const SizedBox(height: FitSpacing.xs),
                    Text(
                      s.tone.description,
                      key: const ValueKey('notify.tone.description'),
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                    ),
                    const SizedBox(height: FitSpacing.lg),
                    Text('WHAT TO SEND', style: textTheme.labelSmall),
                    Divider(color: FitColors.rule, height: 1),
                    for (final k in NotifyKind.values)
                      _KindRow(
                        kind: k,
                        on: s.kinds[k] ?? false,
                        next: [
                          for (final u in upcoming)
                            if (u.kind == k.wire) u,
                        ].firstOrNull,
                        when: _when,
                        onChanged: _saving
                            ? null
                            : (v) => _update(
                                  {
                                    'kinds': {k.wire: v},
                                  },
                                  _with(s, kinds: {...s.kinds, k: v}),
                                ),
                      ),
                    const SizedBox(height: FitSpacing.lg),
                    Text('QUIET HOURS', style: textTheme.labelSmall),
                    Divider(color: FitColors.rule, height: 1),
                    _ClockRow(
                      keyName: 'notify.quietStart',
                      label: 'Nothing after',
                      value: s.quietStart,
                      onTap: _saving ? null : () => _pickTime(s, start: true),
                    ),
                    _ClockRow(
                      keyName: 'notify.quietEnd',
                      label: 'Nothing before',
                      value: s.quietEnd,
                      onTap: _saving ? null : () => _pickTime(s, start: false),
                    ),
                    const SizedBox(height: FitSpacing.lg),
                    Text('COMING UP', style: textTheme.labelSmall),
                    Divider(color: FitColors.rule, height: 1),
                    if (upcoming.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: FitSpacing.md),
                        child: Text(
                          notify.plan == null
                              ? 'The plan arrives the next time FITOS reaches the server.'
                              : 'Nothing planned right now.',
                          key: const ValueKey('notify.upcoming.empty'),
                          style: textTheme.bodyMedium
                              ?.copyWith(color: FitColors.ink60),
                        ),
                      ),
                    for (final (i, u) in upcoming.take(6).indexed)
                      Padding(
                        key: ValueKey('notify.upcoming.$i'),
                        padding:
                            const EdgeInsets.symmetric(vertical: FitSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${_when(u.at)} · ${u.notifyKind?.label ?? u.kind}',
                              style: textTheme.labelSmall,
                            ),
                            Text(u.title, style: textTheme.titleMedium),
                            Text(u.body, style: textTheme.bodyMedium),
                            Text(
                              u.why,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: FitColors.ink60),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: FitSpacing.md),
                    OutlinedButton.icon(
                      key: const ValueKey('notify.sample'),
                      style: OutlinedButton.styleFrom(
                        shape: const RoundedRectangleBorder(),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _trySample(s),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Send me a sample'),
                    ),
                    if (_sample case final sample?)
                      Padding(
                        padding: const EdgeInsets.only(top: FitSpacing.sm),
                        child: Text(
                          sample,
                          key: const ValueKey('notify.sample.text'),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('notify.permission'),
      margin: const EdgeInsets.only(bottom: FitSpacing.md),
      padding: const EdgeInsets.all(FitSpacing.md),
      decoration: BoxDecoration(border: Border.all(color: FitColors.amber)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Notifications are off for FITOS on this phone',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            'The reminders are planned, but Android will not show them until '
            'you allow notifications.',
            style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.sm),
          FilledButton(
            key: const ValueKey('notify.permission.allow'),
            style: FilledButton.styleFrom(
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: onAllow,
            child: const Text('Allow notifications'),
          ),
        ],
      ),
    );
  }
}

class _KindRow extends StatelessWidget {
  const _KindRow({
    required this.kind,
    required this.on,
    required this.next,
    required this.when,
    required this.onChanged,
  });

  final NotifyKind kind;
  final bool on;
  final PlannedNotification? next;
  final String Function(DateTime) when;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final n = next;
    return SwitchListTile(
      key: ValueKey('notify.kind.${kind.wire}'),
      contentPadding: EdgeInsets.zero,
      title: Text(kind.label, style: textTheme.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(kind.description),
          if (on && n != null)
            Text(
              'Next: ${when(n.at)}',
              key: ValueKey('notify.next.${kind.wire}'),
              style: textTheme.bodySmall?.copyWith(color: FitColors.pine),
            ),
        ],
      ),
      value: on,
      onChanged: onChanged,
    );
  }
}

class _ClockRow extends StatelessWidget {
  const _ClockRow({
    required this.keyName,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      key: ValueKey(keyName),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FitSpacing.md),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: textTheme.bodyLarge)),
            Text(
              value,
              key: ValueKey('$keyName.value'),
              style: textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
