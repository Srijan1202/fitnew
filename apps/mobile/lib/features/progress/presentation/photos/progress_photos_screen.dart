import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/app_features.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../data/progress_photos.dart';
import 'progress_photos_providers.dart';

const _onlyHere =
    'Photos stay on this phone. Uninstalling FITOS or changing phones loses them; save any photo to keep it.';

String _shortDate(String d) {
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
  final t = DateTime.parse(d);
  return '${t.day} ${months[t.month - 1]} ${t.year}';
}

/// Beta 3.6 (owner): photos stay hidden until asked for, and hide again when
/// FITOS goes to the background, so nobody sees them over a shoulder.
mixin _HiddenUntilShown<T extends StatefulWidget> on State<T> {
  bool shown = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: hide);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void hide() {
    if (shown && mounted) setState(() => shown = false);
  }

  void show() => setState(() => shown = true);
}

String _hiddenLabel(int n) =>
    n == 1 ? '1 photo · hidden' : '$n photos · hidden';

/// Progress → Photos: the newest few (once shown), and ways in.
class ProgressPhotosCard extends ConsumerStatefulWidget {
  const ProgressPhotosCard({super.key});

  @override
  ConsumerState<ProgressPhotosCard> createState() => _ProgressPhotosCardState();
}

class _ProgressPhotosCardState extends ConsumerState<ProgressPhotosCard>
    with _HiddenUntilShown {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final photos = ref.watch(progressPhotosProvider).value ?? const [];
    return Column(
      key: const ValueKey('photos.card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (photos.isEmpty)
          Text(
            'Take a photo now and another in a few weeks: the change is easier to see than to weigh.',
            style: textTheme.bodyMedium,
          )
        else if (!shown)
          Row(
            children: <Widget>[
              Icon(Icons.visibility_off_outlined, color: FitColors.ink60),
              const SizedBox(width: FitSpacing.sm),
              Expanded(
                child: Text(
                  _hiddenLabel(photos.length),
                  key: const ValueKey('photos.hidden'),
                  style: textTheme.bodyMedium,
                ),
              ),
              TextButton(
                key: const ValueKey('photos.show'),
                onPressed: show,
                child: const Text('Show photos'),
              ),
            ],
          )
        else
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final x in photos.take(6))
                  Padding(
                    padding: const EdgeInsets.only(right: FitSpacing.sm),
                    child: _Thumb(photo: x, width: 72),
                  ),
              ],
            ),
          ),
        const SizedBox(height: FitSpacing.sm),
        Text(
          _onlyHere,
          style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
        ),
        const SizedBox(height: FitSpacing.sm),
        // Wraps at large text sizes (360 px at 200 %).
        Wrap(
          spacing: FitSpacing.sm,
          runSpacing: FitSpacing.xs,
          children: <Widget>[
            FilledButton.icon(
              key: const ValueKey('photos.add'),
              onPressed: () => addProgressPhoto(context, ref),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add photo'),
            ),
            if (photos.isNotEmpty)
              OutlinedButton(
                key: const ValueKey('photos.all'),
                onPressed: () => context.push(Routes.progressPhotos),
                child:
                    Text(photos.length >= 2 ? 'See all · Compare' : 'See all'),
              ),
            // Beta 4.1.1 (owner): shown photos can be hidden again.
            if (photos.isNotEmpty && shown)
              TextButton.icon(
                key: const ValueKey('photos.hide'),
                onPressed: hide,
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Hide photos'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Camera or gallery, then the pose and the day; saved on the phone.
///
/// Beta 3.6: the camera sends FITOS to the background, and on return the
/// screen that asked may be rebuilt (fresh switches, health, sync). So once
/// the photo is picked, the rest runs on the app's own navigator and
/// provider container, never on that screen: the photo is not dropped.
Future<void> addProgressPhoto(BuildContext context, WidgetRef ref) async {
  final camera = await showModalBottomSheet<bool>(
    // Above the floating tab bar (beta 4.8, owner: Save hid behind it).
    useRootNavigator: true,
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            key: const ValueKey('photos.source.camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(ctx).pop(true),
          ),
          ListTile(
            key: const ValueKey('photos.source.gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    ),
  );
  if (camera == null || !context.mounted) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final navigator = Navigator.of(context, rootNavigator: true);
  final source = await container
      .read(photoSourceProvider)
      .pick(camera: camera, navigator: navigator);
  if (source == null || !navigator.mounted) return;
  await finishProgressPhoto(navigator.context, container, source);
}

/// The pose and the day for a picked photo, then saved.
Future<void> finishProgressPhoto(
  BuildContext context,
  ProviderContainer container,
  String source,
) async {
  final today = container.read(eatDateProvider.notifier).today;
  final details = await showDialog<(PhotoPose, String)>(
    context: context,
    builder: (_) => _DetailsDialog(today: today),
  );
  if (details == null) return;
  await container.read(progressPhotosProvider.notifier).add(
        source: source,
        date: details.$2,
        pose: details.$1,
      );
}

/// Beta 3.6: if Android closed FITOS while the camera was open, the photo is
/// handed back on the next start; this offers to finish adding it. Once per
/// start, signed in, with photos switched on, never during a workout.
class LostPhotoHost extends ConsumerStatefulWidget {
  const LostPhotoHost({this.navigatorContext, this.suppressed, super.key});

  /// The root navigator's context; this widget's own context when null.
  final BuildContext? Function()? navigatorContext;

  /// True while the question must wait (tried again on the next build).
  final bool Function()? suppressed;

  @override
  ConsumerState<LostPhotoHost> createState() => _LostPhotoHostState();
}

class _LostPhotoHostState extends ConsumerState<LostPhotoHost> {
  bool _asked = false;

  void _maybeAsk() {
    if (_asked) return;
    _asked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final container = ProviderScope.containerOf(context, listen: false);
      final source = await container.read(photoSourceProvider).recoverLost();
      if (source == null || !mounted) return;
      final dialogContext = widget.navigatorContext?.call() ?? context;
      if (!dialogContext.mounted || (widget.suppressed?.call() ?? false)) {
        _asked = false; // try again on a later build
        return;
      }
      final finish = await showDialog<bool>(
        context: dialogContext,
        builder: (ctx) => AlertDialog(
          key: const ValueKey('photos.lost'),
          title: const Text('Finish adding your progress photo?'),
          content: const Text(
            'FITOS was closed while the camera was open. Your photo was kept.',
          ),
          actions: <Widget>[
            TextButton(
              key: const ValueKey('photos.lost.discard'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Discard'),
            ),
            FilledButton(
              key: const ValueKey('photos.lost.add'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add photo'),
            ),
          ],
        ),
      );
      if ((finish ?? false) && dialogContext.mounted) {
        await finishProgressPhoto(dialogContext, container, source);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(sessionUserIdProvider) != null;
    final on = ref.watch(featureOnProvider(AppFeature.progressPhotos));
    if (signedIn && on) _maybeAsk();
    return const SizedBox.shrink();
  }
}

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({required this.today});

  final String today;

  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  PhotoPose _pose = PhotoPose.front;
  late String _date = widget.today;

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const ValueKey('photos.details'),
        backgroundColor: FitColors.paper,
        title: const Text('Which photo is it?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: FitSpacing.xs,
              children: <Widget>[
                for (final pose in PhotoPose.values)
                  ChoiceChip(
                    key: ValueKey('photos.pose.${pose.name}'),
                    label: Text(pose.label),
                    selected: _pose == pose,
                    onSelected: (_) => setState(() => _pose = pose),
                  ),
              ],
            ),
            const SizedBox(height: FitSpacing.sm),
            TextButton.icon(
              key: const ValueKey('photos.date'),
              icon: const Icon(Icons.event_outlined),
              label: Text(_date == widget.today ? 'Today' : _shortDate(_date)),
              onPressed: () async {
                final today = DateTime.parse(widget.today);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse(_date),
                  firstDate: today.subtract(const Duration(days: 365 * 3)),
                  lastDate: today,
                );
                if (picked != null) {
                  setState(
                    () => _date = picked.toIso8601String().substring(0, 10),
                  );
                }
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('photos.save'),
            onPressed: () => Navigator.of(context).pop((_pose, _date)),
            child: const Text('Save'),
          ),
        ],
      );
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photo,
    required this.width,
    this.onTap,
    this.selected = false,
  });

  final ProgressPhoto photo;
  final double width;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => InkWell(
        key: ValueKey('photos.thumb.${photo.id}'),
        onTap: onTap,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            border: Border.all(
              color: selected ? FitColors.accent : Colors.transparent,
              width: 3,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              cacheWidth: (width * 3).round(),
              errorBuilder: (_, __, ___) => ColoredBox(color: FitColors.paper2),
            ),
          ),
        ),
      );
}

/// All photos, a pose filter, and compare.
class ProgressPhotosScreen extends ConsumerStatefulWidget {
  const ProgressPhotosScreen({super.key});

  @override
  ConsumerState<ProgressPhotosScreen> createState() =>
      _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends ConsumerState<ProgressPhotosScreen>
    with _HiddenUntilShown {
  PhotoPose? _pose;

  void _compare(List<ProgressPhoto> photos) {
    // The oldest and newest of the pose with the most photos (or the filter).
    final byPose = <PhotoPose, List<ProgressPhoto>>{};
    for (final x in photos) {
      (byPose[x.pose] ??= []).add(x);
    }
    final pool = _pose != null
        ? (byPose[_pose] ?? const <ProgressPhoto>[])
        : (byPose.values.toList()..sort((a, b) => b.length - a.length)).first;
    final list = pool.length >= 2 ? pool : photos;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComparePhotosScreen(
          photos: photos,
          before: list.last,
          after: list.first,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final all = ref.watch(progressPhotosProvider).value ?? const [];
    final visible =
        _pose == null ? all : all.where((x) => x.pose == _pose).toList();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: const Text('Progress photos'),
        actions: <Widget>[
          if (shown && all.length >= 2)
            TextButton(
              key: const ValueKey('photos.compare'),
              onPressed: () => _compare(all),
              child: const Text('Compare'),
            ),
          if (shown && all.isNotEmpty)
            IconButton(
              key: const ValueKey('photos.hide'),
              tooltip: 'Hide photos',
              onPressed: hide,
              icon: const Icon(Icons.visibility_off_outlined),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('photos.fab'),
        onPressed: () => addProgressPhoto(context, ref),
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: FitBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(FitSpacing.screen),
            children: <Widget>[
              Wrap(
                spacing: FitSpacing.xs,
                children: <Widget>[
                  ChoiceChip(
                    key: const ValueKey('photos.filter.all'),
                    label: const Text('All'),
                    selected: _pose == null,
                    onSelected: (_) => setState(() => _pose = null),
                  ),
                  for (final pose in PhotoPose.values)
                    ChoiceChip(
                      key: ValueKey('photos.filter.${pose.name}'),
                      label: Text(pose.label),
                      selected: _pose == pose,
                      onSelected: (_) => setState(() => _pose = pose),
                    ),
                ],
              ),
              const SizedBox(height: FitSpacing.sm),
              Text(
                _onlyHere,
                style: textTheme.bodySmall?.copyWith(color: FitColors.ink60),
              ),
              const SizedBox(height: FitSpacing.md),
              if (visible.isEmpty)
                Text('No photos here yet.', style: textTheme.bodyMedium)
              else if (!shown)
                Column(
                  children: <Widget>[
                    const SizedBox(height: FitSpacing.lg),
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 40,
                      color: FitColors.ink60,
                    ),
                    const SizedBox(height: FitSpacing.sm),
                    Text(
                      _hiddenLabel(visible.length),
                      key: const ValueKey('photos.hidden'),
                      style: textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: FitSpacing.sm),
                    FilledButton.icon(
                      key: const ValueKey('photos.show'),
                      onPressed: show,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Show photos'),
                    ),
                  ],
                )
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: FitSpacing.sm,
                  crossAxisSpacing: FitSpacing.sm,
                  childAspectRatio: 3 / 4,
                  children: <Widget>[
                    for (final x in visible)
                      LayoutBuilder(
                        builder: (context, c) => _Thumb(
                          photo: x,
                          width: c.maxWidth,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _PhotoView(photo: x),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoView extends ConsumerWidget {
  const _PhotoView({required this.photo});

  final ProgressPhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = photo.weightKg;
    return Scaffold(
      appBar: AppBar(
        title: Text('${_shortDate(photo.date)} · ${photo.pose.label}'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey('photos.save.gallery'),
            tooltip: 'Save or share',
            icon: const Icon(Icons.ios_share),
            onPressed: () => SharePlus.instance.share(
              ShareParams(files: [XFile(photo.path, mimeType: 'image/jpeg')]),
            ),
          ),
          IconButton(
            key: const ValueKey('photos.delete'),
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete this photo?'),
                  content: const Text(
                    'It is removed from this phone. There is no copy anywhere else.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      key: const ValueKey('photos.delete.confirm'),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await ref.read(progressPhotosProvider.notifier).delete(photo.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: InteractiveViewer(
              child: Center(child: Image.file(File(photo.path))),
            ),
          ),
          if (w != null)
            Padding(
              padding: const EdgeInsets.all(FitSpacing.md),
              child: Text('Trend weight that day: ${w.toStringAsFixed(1)} kg'),
            ),
        ],
      ),
    );
  }
}

/// Two photos side by side, or one over the other with a slider.
class ComparePhotosScreen extends StatefulWidget {
  const ComparePhotosScreen({
    required this.photos,
    required this.before,
    required this.after,
    super.key,
  });

  final List<ProgressPhoto> photos;
  final ProgressPhoto before;
  final ProgressPhoto after;

  @override
  State<ComparePhotosScreen> createState() => _ComparePhotosScreenState();
}

class _ComparePhotosScreenState extends State<ComparePhotosScreen> {
  late ProgressPhoto _before = widget.before;
  late ProgressPhoto _after = widget.after;
  bool _slider = false;
  double _split = 0.5;

  String get _summary {
    final (a, b) = _before.date.compareTo(_after.date) <= 0
        ? (_before, _after)
        : (_after, _before);
    final days =
        DateTime.parse(b.date).difference(DateTime.parse(a.date)).inDays;
    final parts = <String>['$days ${days == 1 ? 'day' : 'days'} apart'];
    if (a.weightKg != null && b.weightKg != null) {
      final d = b.weightKg! - a.weightKg!;
      parts.add('${d >= 0 ? '+' : '−'}${d.abs().toStringAsFixed(1)} kg');
    }
    return parts.join(' · ');
  }

  Future<void> _pick(bool before) async {
    final chosen = await showModalBottomSheet<ProgressPhoto>(
      // Above the floating tab bar (beta 4.8, owner: Save hid behind it).
      useRootNavigator: true,
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: GridView.count(
          crossAxisCount: 4,
          padding: const EdgeInsets.all(FitSpacing.md),
          mainAxisSpacing: FitSpacing.sm,
          crossAxisSpacing: FitSpacing.sm,
          childAspectRatio: 3 / 4,
          children: <Widget>[
            for (final x in widget.photos)
              LayoutBuilder(
                builder: (_, c) => _Thumb(
                  photo: x,
                  width: c.maxWidth,
                  selected: x.id == (before ? _before.id : _after.id),
                  onTap: () => Navigator.of(ctx).pop(x),
                ),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    setState(() => before ? _before = chosen : _after = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget labelled(ProgressPhoto x, bool before) => Expanded(
          child: Column(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  key: ValueKey(before ? 'compare.before' : 'compare.after'),
                  onTap: () => _pick(before),
                  child: Image.file(File(x.path), fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(_shortDate(x.date), style: textTheme.titleSmall),
              if (x.weightKg != null)
                Text(
                  '${x.weightKg!.toStringAsFixed(1)} kg',
                  style: textTheme.bodySmall,
                ),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey('compare.mode'),
            tooltip: _slider ? 'Side by side' : 'Slider',
            icon: Icon(_slider ? Icons.view_column_outlined : Icons.compare),
            onPressed: () => setState(() => _slider = !_slider),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(FitSpacing.md),
              child: Text(
                _summary,
                key: const ValueKey('compare.summary'),
                style: textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: _slider
                  ? LayoutBuilder(
                      builder: (_, c) => Stack(
                        key: const ValueKey('compare.slider'),
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.file(File(_after.path), fit: BoxFit.contain),
                          ClipRect(
                            clipper: _LeftPart(_split),
                            child: Image.file(
                              File(_before.path),
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            left: math.max(0, c.maxWidth * _split - 1),
                            top: 0,
                            bottom: 0,
                            child: Container(width: 2, color: FitColors.accent),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: <Widget>[
                        labelled(_before, true),
                        labelled(_after, false),
                      ],
                    ),
            ),
            if (_slider)
              Slider(
                key: const ValueKey('compare.split'),
                value: _split,
                onChanged: (v) => setState(() => _split = v),
              ),
          ],
        ),
      ),
    );
  }
}

class _LeftPart extends CustomClipper<Rect> {
  const _LeftPart(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_LeftPart old) => old.fraction != fraction;
}
