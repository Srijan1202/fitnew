import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fitos_wordmark.dart';
import '../../domain/gpx.dart';
import '../../domain/run.dart';
import '../../domain/track.dart';
import '../../domain/units.dart';
import '../controllers/running_providers.dart';
import '../widgets/route_painter.dart';
import '../widgets/route_snapshot.dart';
import '../widgets/run_map.dart';

/// Beta 4.0 (ADR-038): share a run — a picture of the route with its
/// figures, or the GPX file for Strava, Garmin and others. The privacy zone
/// is on by default: the first and last 200 m are left out of both, so a
/// shared map does not lead to your door.

/// Hands a file to Android's share sheet; tests record instead.
abstract class RunSharer {
  Future<void> share(Uint8List bytes, String fileName, String mimeType);
}

class SystemRunSharer implements RunSharer {
  @override
  Future<void> share(Uint8List bytes, String fileName, String mimeType) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
    );
  }
}

final runSharerProvider = Provider<RunSharer>((_) => SystemRunSharer());

class ShareRunScreen extends ConsumerStatefulWidget {
  const ShareRunScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<ShareRunScreen> createState() => _ShareRunScreenState();
}

class _ShareRunScreenState extends ConsumerState<ShareRunScreen> {
  bool _hideEnds = true;
  final _card = GlobalKey();
  bool _busy = false;

  // Beta 4.1.1 (owner): the map is made as a picture with the route in it
  // (route_snapshot.dart) as soon as the screen opens, so the card shown is
  // the picture shared. Until then the live map; if it cannot be made
  // (offline), FITOS's own drawn route.
  Uint8List? _mapImage;
  bool _drawn = false;
  Future<void>? _preparing;
  int _generation = 0;

  Track _shown(Track track) => _hideEnds ? hideEnds(track) : track;

  Future<void> _prepare(List<List<(double, double)>> segments) async {
    final generation = ++_generation;
    final image = await ref.read(routeSnapshotterProvider).take(segments);
    if (!mounted || generation != _generation) return;
    setState(() {
      _mapImage = image;
      _drawn = image == null;
    });
  }

  Future<void> _sharePicture(RunDetail run) async {
    setState(() => _busy = true);
    try {
      // The map is a platform view and cannot be captured: wait for its
      // picture (or the drawn route) before capturing the card.
      await _preparing;
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (_mapImage != null && mounted) {
        // Let the picture decode before the capture.
        await precacheImage(MemoryImage(_mapImage!), context);
        await WidgetsBinding.instance.endOfFrame;
      }
      final boundary =
          _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return;
      await ref.read(runSharerProvider).share(
            png.buffer.asUint8List(),
            gpxFileName(run.summary.name, run.summary.startedAt.toLocal())
                .replaceAll('.gpx', '.png'),
            'image/png',
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareGpx(RunDetail run) async {
    final gpx = toGpx(
      name: run.summary.name,
      startedAt: run.summary.startedAt,
      track: _shown(run.track!),
      note: run.note,
    );
    await ref.read(runSharerProvider).share(
          Uint8List.fromList(gpx.codeUnits),
          gpxFileName(run.summary.name, run.summary.startedAt.toLocal()),
          'application/gpx+xml',
        );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(runDetailProvider(widget.id));
    final unit = ref.watch(runSettingsProvider).unit;
    final t = Theme.of(context).textTheme;
    final run = async.value;
    if (run == null || run.track == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Share run')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final shown = _shown(run.track!);
    final segments = [
      for (final s in shown.segments) [for (final p in s) (p.lat, p.lon)],
    ];
    if (_preparing == null && segments.isNotEmpty) {
      _preparing = _prepare(segments);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Share run')),
      body: ListView(
        key: const ValueKey('share.list'),
        padding: const EdgeInsets.all(FitSpacing.screen),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: RepaintBoundary(
              key: _card,
              child: _Card(
                run: run,
                unit: unit,
                map: _mapImage != null
                    ? Image.memory(
                        _mapImage!,
                        key: const ValueKey('share.map.picture'),
                        fit: BoxFit.cover,
                      )
                    : segments.isEmpty
                        ? Center(
                            child: Text(
                              'Too short to show a route with the start and '
                              'end hidden.',
                              textAlign: TextAlign.center,
                              style: t.bodyMedium,
                            ),
                          )
                        : _drawn
                            ? ColoredBox(
                                key: const ValueKey('share.map.drawn'),
                                color: FitColors.paper2,
                                child:
                                    RouteView(segments: segments, grid: true),
                              )
                            : RunMap(
                                key: ValueKey('share.map.$_hideEnds'),
                                segments: segments,
                                interactive: false,
                              ),
              ),
            ),
          ),
          const SizedBox(height: FitSpacing.md),
          SwitchListTile(
            key: const ValueKey('share.hideEnds'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide the start and the end'),
            subtitle: const Text(
              'Leaves out the first and last 200 m, so the map does not show '
              'where you live. For the picture and the GPX file.',
            ),
            value: _hideEnds,
            onChanged: (v) => setState(() {
              _hideEnds = v;
              _mapImage = null;
              _drawn = false;
              _preparing = null; // made again for the new route
            }),
          ),
          const SizedBox(height: FitSpacing.md),
          FilledButton.icon(
            key: const ValueKey('share.picture'),
            onPressed: _busy ? null : () => _sharePicture(run),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Share picture'),
          ),
          const SizedBox(height: FitSpacing.sm),
          OutlinedButton.icon(
            key: const ValueKey('share.gpx'),
            onPressed: _busy ? null : () => _shareGpx(run),
            icon: const Icon(Icons.route),
            label: const Text('Export GPX (Strava, Garmin…)'),
          ),
          const SizedBox(height: FitSpacing.sm),
          Text(
            'Map © OpenStreetMap contributors, OpenFreeMap.',
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.run,
    required this.unit,
    required this.map,
  });

  final RunDetail run;
  final DistanceUnit unit;
  final Widget map;

  @override
  Widget build(BuildContext context) {
    final s = run.summary;
    final t = Theme.of(context).textTheme;
    const on = FitBrand.limeHi;
    TextStyle? big(TextStyle? x) => x?.copyWith(
          color: Colors.white,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    Widget stat(String value, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: big(t.displaySmall)),
            Text(label.toUpperCase(), style: t.labelSmall?.copyWith(color: on)),
          ],
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: FitBrand.carbon,
        child: Stack(
          fit: StackFit.expand,
          children: [
            map,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0xE60A0D0B),
                  ],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: stat(
                          formatDistance(s.distanceM, unit),
                          unit.label,
                        ),
                      ),
                      Expanded(
                        child: stat(formatDuration(s.durationSeconds), 'Time'),
                      ),
                      Expanded(
                        child: stat(
                          formatPace(s.avgPaceSecPerKm, unit),
                          'Pace ${unit.paceLabel}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 14,
              right: 14,
              child: FitosWordmark(size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
