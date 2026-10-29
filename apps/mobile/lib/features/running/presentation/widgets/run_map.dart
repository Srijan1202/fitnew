import 'dart:async';
import 'dart:math' as math;

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

/// The route's colour on the map ("#rrggbb", the theme's glow); also the
/// share picture's (route_snapshot.dart).
String mapLineColour() {
  final c = FitPalette.current.glow;
  String hex(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${hex(c.r)}${hex(c.g)}${hex(c.b)}';
}

class RunMap extends ConsumerWidget {
  const RunMap({
    required this.segments,
    this.follow = false,
    this.interactive = true,
    this.position,
    this.coloured,
    this.under = false,
    this.frame,
    super.key,
  });

  /// [lat, lon] pairs, one list per stretch between pauses.
  final List<List<(double, double)>> segments;

  /// The live view: the camera keeps the runner in the middle.
  final bool follow;
  final bool interactive;
  final (double, double)? position;

  /// Beta 4.4: stretches in their own colours (pace) instead of the one
  /// route colour.
  final List<(List<(double, double)>, Color)>? coloured;

  /// Beta 4.4 (the replay): [segments] faint under [coloured].
  final bool under;

  /// Beta 4.4 (the replay): what the camera frames (the whole route), while
  /// [segments] grow; [segments] when null.
  final List<List<(double, double)>>? frame;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(mapOnlineProvider).value ?? true;
    final drawn = ref.watch(runMapModeProvider) == RunMapMode.drawn || !online;
    if (drawn) {
      return Semantics(
        label: 'Route map',
        child: ColoredBox(
          color: FitColors.paper2,
          child: RouteView(
            segments: frame ?? segments,
            grid: true,
            position: position,
            coloured: coloured,
            under: under || frame != null,
            endpoints: frame == null,
          ),
        ),
      );
    }
    return _TileMap(
      segments: segments,
      follow: follow,
      interactive: interactive,
      position: position,
      coloured: coloured,
      under: under,
      frame: frame,
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
    required this.dark,
    this.coloured,
    this.under = false,
    this.frame,
  });

  final List<List<(double, double)>> segments;
  final bool follow;
  final bool interactive;
  final (double, double)? position;
  final bool dark;
  final List<(List<(double, double)>, Color)>? coloured;
  final bool under;
  final List<List<(double, double)>>? frame;

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

  String get _lineColour => mapLineColour();

  /// Each line carries its own colour (beta 4.4: pace colours, and the
  /// replay's faint whole route), read by the layer's colour expression.
  Map<String, dynamic> _lines() {
    final features = <Map<String, dynamic>>[];
    void add(List<(double, double)> pts, String colour) {
      if (pts.length < 2) return;
      features.add({
        'type': 'Feature',
        'id': features.length,
        'properties': <String, dynamic>{'colour': colour},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in pts) [p.$2, p.$1],
          ],
        },
      });
    }

    final coloured = widget.coloured;
    if (coloured == null || widget.under || widget.frame != null) {
      final base = widget.frame ?? widget.segments;
      final faint = coloured != null || widget.frame != null;
      for (final s in base) {
        add(s, faint ? _faint : _lineColour);
      }
    }
    if (coloured != null) {
      for (final (s, c) in coloured) {
        add(s, hexOf(c));
      }
    } else if (widget.frame != null) {
      for (final s in widget.segments) {
        add(s, _lineColour);
      }
    }
    return {'type': 'FeatureCollection', 'features': features};
  }

  /// The route's colour, faint (the replay's road ahead).
  String get _faint {
    final c = FitPalette.current.glow;
    return 'rgba(${(c.r * 255).round()}, ${(c.g * 255).round()}, '
        '${(c.b * 255).round()}, 0.3)';
  }

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
      const LineLayerProperties(
        // Beta 4.4: each line's own colour (pace colours, the replay).
        lineColor: ['get', 'colour'],
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
  }

  Future<void> _camera({bool force = false}) async {
    final map = _map;
    if (map == null || !_styled) return;
    final all = [for (final s in widget.frame ?? widget.segments) ...s];
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
    if (_count != _drawnPoints ||
        !identical(old.segments, widget.segments) ||
        !identical(old.coloured, widget.coloured) ||
        old.position != widget.position) {
      _drawnPoints = _count;
      unawaited(map.setGeoJsonSource(_route, _lines()));
      unawaited(map.setGeoJsonSource(_me, _point()));
      // The replay keeps its frame: the camera moves only when it changes.
      if (widget.frame == null || !identical(old.frame, widget.frame)) {
        unawaited(_camera());
      }
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
