import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
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

/// Progress → Photos: the newest few, and ways in.
class ProgressPhotosCard extends ConsumerWidget {
  const ProgressPhotosCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          ],
        ),
      ],
    );
  }
}

/// Camera or gallery, then the pose and the day; saved on the phone.
Future<void> addProgressPhoto(BuildContext context, WidgetRef ref) async {
  final camera = await showModalBottomSheet<bool>(
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
  final source = await ref.read(photoSourceProvider).pick(camera: camera);
  if (source == null || !context.mounted) return;
  final today = ref.read(eatDateProvider.notifier).today;
  final details = await showDialog<(PhotoPose, String)>(
    context: context,
    builder: (_) => _DetailsDialog(today: today),
  );
  if (details == null) return;
  await ref.read(progressPhotosProvider.notifier).add(
        source: source,
        date: details.$2,
        pose: details.$1,
      );
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

class _ProgressPhotosScreenState extends ConsumerState<ProgressPhotosScreen> {
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
    final shown =
        _pose == null ? all : all.where((x) => x.pose == _pose).toList();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: const Text('Progress photos'),
        actions: <Widget>[
          if (all.length >= 2)
            TextButton(
              key: const ValueKey('photos.compare'),
              onPressed: () => _compare(all),
              child: const Text('Compare'),
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
              if (shown.isEmpty)
                Text('No photos here yet.', style: textTheme.bodyMedium)
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: FitSpacing.sm,
                  crossAxisSpacing: FitSpacing.sm,
                  childAspectRatio: 3 / 4,
                  children: <Widget>[
                    for (final x in shown)
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
