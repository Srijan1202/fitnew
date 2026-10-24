import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/env.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/routing/navigation.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/tokens.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../data/feedback_api.dart';
import '../data/feedback_sources.dart';
import '../../../shared/widgets/fit_glass.dart';

final feedbackApiProvider =
    Provider<FeedbackApi>((ref) => DioFeedbackApi(ref.watch(dioProvider)));

/// Beta 3.6: where feedback pictures and the phone's details come from.
final feedbackPictureSourceProvider = Provider<FeedbackPictureSource>(
  (_) => const DeviceFeedbackPictureSource(),
);
final feedbackDeviceSourceProvider = Provider<FeedbackDeviceSource>(
  (_) => const PlatformFeedbackDeviceSource(),
);

/// The phone and the last screen outside Profile; null where unknown.
final feedbackDeviceProvider = FutureProvider.autoDispose<FeedbackDevice?>(
  (ref) => ref
      .watch(feedbackDeviceSourceProvider)
      .device(screen: ref.read(lastScreenProvider)),
);

/// Beta 3.6: the person's own messages and the replies; null when offline.
final myFeedbackProvider =
    FutureProvider.autoDispose<MyFeedbackList?>((ref) async {
  final r = await ref.watch(feedbackApiProvider).mine();
  return switch (r) { Ok(:final value) => value, Err() => null };
});

/// How many replies are unread (Profile says so); 0 when unknown.
final feedbackUnreadProvider = FutureProvider.autoDispose<int>(
  (ref) async => (await ref.watch(myFeedbackProvider.future))?.unread ?? 0,
);

String _date(DateTime d) {
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
  final l = d.toLocal();
  return '${l.day} ${months[l.month - 1]}';
}

/// Phase 19 (§31 "feedback channel", ADR-026): Profile → Send feedback. A
/// category and a message; the app adds its version. A failure keeps the
/// text so nothing typed is lost.
///
/// Beta 3.6 (owner): up to three pictures, the phone's model and Android
/// version (shown, and can be left out), and **Your messages**: what was
/// sent, its status and the FITOS team's replies, marked read once seen.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _text = TextEditingController();
  FeedbackCategory? _category;
  bool _busy = false;
  String? _message;
  bool _sent = false;
  final List<Uint8List> _pictures = [];
  bool _withDevice = true;
  bool _markedRead = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _ready =>
      !_busy && _category != null && _text.text.trim().isNotEmpty;

  Future<void> _addPictures() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              key: const ValueKey('feedback.pictures.gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Screenshots or photos'),
              onTap: () => Navigator.of(ctx).pop(false),
            ),
            ListTile(
              key: const ValueKey('feedback.pictures.camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    if (camera == null || !mounted) return;
    final picked = await ref.read(feedbackPictureSourceProvider).pick(
          camera: camera,
          max: kFeedbackMaxPictures - _pictures.length,
        );
    if (!mounted) return;
    final ok = <Uint8List>[];
    var refused = 0;
    for (final p in picked) {
      if (feedbackPictureType(p) == null ||
          p.length > kFeedbackPictureMaxBytes) {
        refused++;
      } else {
        ok.add(p);
      }
    }
    setState(() {
      _pictures.addAll(ok.take(kFeedbackMaxPictures - _pictures.length));
      _sent = false;
      _message = refused == 0
          ? null
          : refused == 1
              ? 'One picture could not be added (too large, or a type FITOS cannot send).'
              : '$refused pictures could not be added (too large, or a type FITOS cannot send).';
    });
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final build = await ref.read(appBuildProvider.future).catchError((_) => 0);
    final device =
        _withDevice ? await ref.read(feedbackDeviceProvider.future) : null;
    final r = await ref.read(feedbackApiProvider).send(
          category: _category!,
          message: _text.text.trim(),
          appVersion: '${Env.appVersion}+$build',
          device: device,
          pictures: List.of(_pictures),
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (r) {
        case Ok():
          _sent = true;
          _text.clear();
          _category = null;
          _pictures.clear();
          _message =
              'Sent. Thank you: the developer reads every one, and any reply shows up below.';
        case Err(:final failure):
          _sent = false;
          _message = switch (failure) {
            Offline() =>
              'Feedback needs a connection. Your text is still here.',
            // The server's hourly limit against spam (20 an hour).
            RateLimited() =>
              'That is a lot of feedback in one hour, thank you! Please send this one a little later. Your text is still here.',
            _ => failure.message,
          };
      }
    });
    if (r is Ok) ref.invalidate(myFeedbackProvider);
  }

  /// Replies shown are read: told to the server once per visit.
  void _markRead(MyFeedbackList mine) {
    if (_markedRead || mine.unread == 0) return;
    _markedRead = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(feedbackApiProvider).markRead();
      if (mounted) ref.invalidate(feedbackUnreadProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final device = ref.watch(feedbackDeviceProvider).value;
    final build = ref.watch(appBuildProvider).value;
    final mine = ref.watch(myFeedbackProvider).value;
    if (mine != null) _markRead(mine);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        centerTitle: false,
        title: Text('SEND FEEDBACK', style: textTheme.labelSmall),
      ),
      body: FitBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              FitSpacing.sm,
              FitSpacing.screen,
              FitSpacing.xl,
            ),
            children: <Widget>[
              Text(
                'Something broke, something is missing, or an idea: it goes '
                'straight to the developer, with the app version. Add a '
                'screenshot if it helps.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: FitSpacing.lg),
              Text('ABOUT', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              Wrap(
                spacing: FitSpacing.sm,
                runSpacing: FitSpacing.sm,
                children: <Widget>[
                  for (final c in FeedbackCategory.values)
                    ChoiceChip(
                      key: ValueKey('feedback.category.${c.wire}'),
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() {
                                _category = c;
                                _sent = false;
                              }),
                    ),
                ],
              ),
              const SizedBox(height: FitSpacing.lg),
              TextField(
                key: const ValueKey('feedback.message'),
                controller: _text,
                enabled: !_busy,
                minLines: 5,
                maxLines: 12,
                maxLength: kFeedbackMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What happened, or what would help?',
                  border: fitGlass
                      ? null
                      : const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                ),
                onChanged: (_) => setState(() => _sent = false),
              ),
              const SizedBox(height: FitSpacing.xs),
              // Beta 3.6: up to three pictures.
              Wrap(
                spacing: FitSpacing.sm,
                runSpacing: FitSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  for (var i = 0; i < _pictures.length; i++)
                    _Thumb(
                      key: ValueKey('feedback.picture.$i'),
                      bytes: _pictures[i],
                      onRemove: _busy
                          ? null
                          : () => setState(() => _pictures.removeAt(i)),
                    ),
                  if (_pictures.length < kFeedbackMaxPictures)
                    OutlinedButton.icon(
                      key: const ValueKey('feedback.pictures.add'),
                      onPressed: _busy ? null : _addPictures,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _pictures.isEmpty
                            ? 'Add a picture'
                            : 'Add (${_pictures.length} of $kFeedbackMaxPictures)',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: FitSpacing.sm),
              // Beta 3.6: the phone, shown before it is sent; can be left out.
              SwitchListTile(
                key: const ValueKey('feedback.device'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Include phone details'),
                subtitle: Text(
                  [
                    if (device != null) device.label,
                    'FITOS ${Env.appVersion}${build == null ? '' : ' ($build)'}',
                  ].join(' · '),
                  key: const ValueKey('feedback.device.label'),
                ),
                value: _withDevice,
                onChanged:
                    _busy ? null : (v) => setState(() => _withDevice = v),
              ),
              const SizedBox(height: FitSpacing.sm),
              FilledButton(
                key: const ValueKey('feedback.send'),
                style: FilledButton.styleFrom(
                  shape: fitGlass ? null : const RoundedRectangleBorder(),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _ready ? _send : null,
                child: Text(_busy ? 'Sending…' : 'Send'),
              ),
              if (_message case final m?)
                Padding(
                  padding: const EdgeInsets.only(top: FitSpacing.sm),
                  child: Text(
                    m,
                    key: const ValueKey('feedback.result'),
                    style: textTheme.bodyMedium?.copyWith(
                      color: _sent ? FitColors.pine : FitColors.oxide,
                    ),
                  ),
                ),
              if (mine != null && mine.items.isNotEmpty) ...<Widget>[
                const SizedBox(height: FitSpacing.xl),
                Text('YOUR MESSAGES', style: textTheme.labelSmall),
                const SizedBox(height: FitSpacing.sm),
                for (final x in mine.items) _Mine(item: x),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.bytes, required this.onRemove, super.key});

  final Uint8List bytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: Image.memory(
              bytes,
              width: 64,
              height: 84,
              fit: BoxFit.cover,
              cacheWidth: 192,
              errorBuilder: (_, __, ___) => Container(
                width: 64,
                height: 84,
                color: FitColors.paper2,
              ),
            ),
          ),
          Positioned(
            top: -10,
            right: -10,
            child: IconButton(
              key: const ValueKey('feedback.picture.remove'),
              tooltip: 'Remove picture',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.cancel, size: 20),
            ),
          ),
        ],
      );
}

/// One of the person's messages: when, about what, its status, and the
/// FITOS team's replies.
class _Mine extends StatelessWidget {
  const _Mine({required this.item});

  final MyFeedback item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FitBlock(
      key: ValueKey('feedback.mine.${item.id}'),
      padding: const EdgeInsets.all(FitSpacing.md),
      flatPadding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
      margin: const EdgeInsets.only(bottom: FitSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            [
              _date(item.createdAt),
              item.category.label,
              item.statusLabel,
              if (item.pictures > 0)
                item.pictures == 1 ? '1 picture' : '${item.pictures} pictures',
            ].join(' · '),
            style: textTheme.labelSmall?.copyWith(color: FitColors.ink60),
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(
            item.message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
          for (final r in item.replies)
            Container(
              key: ValueKey('feedback.reply.${r.id}'),
              width: double.infinity,
              margin: const EdgeInsets.only(top: FitSpacing.sm),
              padding: const EdgeInsets.all(FitSpacing.sm),
              decoration: BoxDecoration(
                color: FitColors.pine.withValues(alpha: 0.10),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'FITOS team · ${_date(r.createdAt)}'
                    '${r.readAt == null ? ' · new' : ''}',
                    style: textTheme.labelSmall?.copyWith(
                      color: FitColors.pine,
                      fontWeight:
                          r.readAt == null ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(r.message, style: textTheme.bodyMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
