import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/tokens.dart';
import 'route_painter.dart';

/// Beta 4.0 (ADR-038): the map. MapLibre draws OpenFreeMap's tiles (free, no
/// key, no account; OpenStreetMap data, credited on the map) in the theme's
/// light or dark style. With no connection — or in tests, which cannot host
/// a platform map — FITOS draws the route itself on a grid; recording never
/// needs the map.

/// OpenFreeMap's styles (openfreemap.org).
const String mapStyleDark = 'https://tiles.openfreemap.org/styles/dark';
const String mapStyleLight = 'https://tiles.openfreemap.org/styles/positron';

enum RunMapMode { tiles, drawn }

/// Tiles in the app; tests override with [RunMapMode.drawn].
final runMapModeProvider = Provider<RunMapMode>((ref) => RunMapMode.tiles);

/// Whether the phone has a network now (tiles need one).
final mapOnlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool on(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);
  try {
    yield on(await c.checkConnectivity());
  } on Object {
    yield true;
  }
  yield* c.onConnectivityChanged.map(on);
});

/// Takes a picture of the map as it is (the share card). Null when the map
/// is FITOS's own drawing.
typedef MapSnapshot = Future<Uint8List?> Function({int? width, int? height});

class RunMap extends ConsumerWidget {
  const RunMap({
    required this.segments,
    this.follow = false,
    this.interactive = true,
    this.position,
    this.onSnapshotReady,
    super.key,
  });

  /// [lat, lon] pairs, one list per stretch between pauses.
  final List<List<(double, double)>> segments;

  /// The live view: the camera keeps the runner in the middle.
  final bool follow;
  final bool interactive;
  final (double, double)? position;

  /// Handed a snapshot function once the map has drawn the route.
  final ValueChanged<MapSnapshot>? onSnapshotReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(mapOnlineProvider).value ?? true;
    final drawn = ref.watch(runMapModeProvider) == RunMapMode.drawn || !online;
    if (drawn) {
      return Semantics(
        label: 'Route map',
        child: ColoredBox(
          color: FitColors.paper2,
          child: RouteView(segments: segments, grid: true, position: position),
        ),
      );
    }
    return _TileMap(
      segments: segments,
      follow: follow,
      interactive: interactive,
      position: position,
      onSnapshotReady: onSnapshotReady,
      dark: FitPalette.current.brightness == Brightness.dark,
    );
  }
}

class _TileMap extends StatefulWidget {
  const _TileMap({
    required this.segments,
    required this.follow,
    required this.interactive,
    required this.position,
    required this.onSnapshotReady,
    required this.dark,
  });

  final List<List<(double, double)>> segments;
  final bool follow;
  final bool interactive;
  final (double, double)? position;
  final ValueChanged<MapSnapshot>? onSnapshotReady;
  final bool dark;

  @override
  State<_TileMap> createState() => _TileMapState();
}

class _TileMapState extends State<_TileMap> {
  MapLibreMapController? _map;
  bool _styled = false;
  int _drawnPoints = -1;
  DateTime _lastCamera = DateTime.fromMillisecondsSinceEpoch(0);

  static const _route = 'fitos-route';
  static const _me = 'fitos-me';

  String get _lineColour {
    final c = FitPalette.current.glow;
    String hex(double v) =>
        (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${hex(c.r)}${hex(c.g)}${hex(c.b)}';
  }

  Map<String, dynamic> _lines() => {
        'type': 'FeatureCollection',
        'features': [
          for (var i = 0; i < widget.segments.length; i++)
            if (widget.segments[i].length >= 2)
              {
                'type': 'Feature',
                'id': i,
                'properties': <String, dynamic>{},
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    for (final p in widget.segments[i]) [p.$2, p.$1],
                  ],
                },
              },
        ],
      };

  Map<String, dynamic> _point() {
    final p = widget.position ??
        (widget.segments.isNotEmpty && widget.segments.last.isNotEmpty
            ? widget.segments.last.last
            : null);
    return {
      'type': 'FeatureCollection',
      'features': [
        if (p != null)
          {
            'type': 'Feature',
            'id': 0,
            'properties': <String, dynamic>{},
            'geometry': {
              'type': 'Point',
              'coordinates': [p.$2, p.$1],
            },
          },
      ],
    };
  }

  int get _count => widget.segments.fold(0, (n, s) => n + s.length);

  Future<void> _onStyle() async {
    final map = _map;
    if (map == null) return;
    await map.addGeoJsonSource(_route, _lines());
    await map.addLineLayer(
      _route,
      '$_route-line',
      LineLayerProperties(
        lineColor: _lineColour,
        lineWidth: 5,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await map.addGeoJsonSource(_me, _point());
    await map.addCircleLayer(
      _me,
      '$_me-dot',
      CircleLayerProperties(
        circleRadius: 7,
        circleColor: _lineColour,
        circleStrokeColor: widget.dark ? '#0A0D0B' : '#FFFFFF',
        circleStrokeWidth: 2,
      ),
    );
    _styled = true;
    _drawnPoints = _count;
    await _camera(force: true);
    widget.onSnapshotReady?.call(_snapshot);
  }

  Future<Uint8List?> _snapshot({int? width, int? height}) async {
    final map = _map;
    if (map == null) return null;
    try {
      await map.waitUntilMapTilesAreLoaded();
      return await map.takeSnapshot(width: width, height: height);
    } on Object {
      return null;
    }
  }

  Future<void> _camera({bool force = false}) async {
    final map = _map;
    if (map == null || !_styled) return;
    final all = [for (final s in widget.segments) ...s];
    if (all.isEmpty) return;
    if (widget.follow) {
      final now = DateTime.now();
      if (!force && now.difference(_lastCamera) < const Duration(seconds: 2)) {
        return;
      }
      _lastCamera = now;
      final p = widget.position ?? all.last;
      await map.animateCamera(CameraUpdate.newLatLng(LatLng(p.$1, p.$2)));
      return;
    }
    var minLat = all.first.$1, maxLat = all.first.$1;
    var minLon = all.first.$2, maxLon = all.first.$2;
    for (final p in all) {
      minLat = math.min(minLat, p.$1);
      maxLat = math.max(maxLat, p.$1);
      minLon = math.min(minLon, p.$2);
      maxLon = math.max(maxLon, p.$2);
    }
    await map.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLon),
          northeast: LatLng(maxLat, maxLon),
        ),
        left: 40,
        top: 40,
        right: 40,
        bottom: 40,
      ),
    );
  }

  @override
  void didUpdateWidget(_TileMap old) {
    super.didUpdateWidget(old);
    final map = _map;
    if (map == null || !_styled) return;
    if (_count != _drawnPoints || !identical(old.segments, widget.segments)) {
      _drawnPoints = _count;
      unawaited(map.setGeoJsonSource(_route, _lines()));
      unawaited(map.setGeoJsonSource(_me, _point()));
      unawaited(_camera());
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = [for (final s in widget.segments) ...s];
    final start = widget.position ?? (all.isEmpty ? null : all.last);
    // Following the runner, the map only zooms: the camera stays on them.
    final pan = widget.interactive && !widget.follow;
    return MapLibreMap(
      styleString: widget.dark ? mapStyleDark : mapStyleLight,
      initialCameraPosition: CameraPosition(
        // Vellore until the first fix.
        target: start == null
            ? const LatLng(12.9692, 79.1559)
            : LatLng(start.$1, start.$2),
        zoom: 15.5,
      ),
      onMapCreated: (c) => _map = c,
      onStyleLoadedCallback: () => unawaited(_onStyle()),
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      scrollGesturesEnabled: pan,
      zoomGesturesEnabled: widget.interactive,
      dragEnabled: pan,
      attributionButtonPosition: AttributionButtonPosition.bottomLeft,
    );
  }
}
