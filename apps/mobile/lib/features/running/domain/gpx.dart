import 'track.dart';

/// Beta 4.0: the privacy zone and the GPX file.
///
/// The privacy zone (owner default 200 m) hides the first and last stretch
/// of a route on anything that leaves the phone — the share card and GPX —
/// so a shared map does not lead to your door. It is applied by distance
/// along the route: a run shorter than twice the zone shares no route.
const double defaultPrivacyZoneM = 200;

/// The track without its first and last [zoneM] metres.
Track hideEnds(Track track, {double zoneM = defaultPrivacyZoneM}) {
  if (zoneM <= 0) return track;
  // Distance from the start at every point (pause gaps add nothing).
  final along = <List<double>>[];
  var d = 0.0;
  for (final seg in track.segments) {
    final row = <double>[];
    for (var i = 0; i < seg.length; i++) {
      if (i > 0) d += distanceBetween(seg[i - 1], seg[i]);
      row.add(d);
    }
    along.add(row);
  }
  final total = d;
  if (total <= 2 * zoneM) return const Track([]);
  final out = <List<TrackPoint>>[];
  for (var s = 0; s < track.segments.length; s++) {
    final kept = <TrackPoint>[
      for (var i = 0; i < track.segments[s].length; i++)
        if (along[s][i] >= zoneM && along[s][i] <= total - zoneM)
          track.segments[s][i],
    ];
    if (kept.isNotEmpty) out.add(kept);
  }
  return Track(out);
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// A GPX 1.1 file: one track, one segment per stretch between pauses, with
/// elevation and time. Strava, Garmin Connect and most apps import it.
String toGpx({
  required String name,
  required DateTime startedAt,
  required Track track,
  String? note,
}) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<gpx version="1.1" creator="FITOS" '
      'xmlns="http://www.topografix.com/GPX/1/1">',
    )
    ..writeln('  <metadata>')
    ..writeln('    <name>${_esc(name)}</name>')
    ..writeln('    <time>${startedAt.toUtc().toIso8601String()}</time>')
    ..writeln('  </metadata>')
    ..writeln('  <trk>')
    ..writeln('    <name>${_esc(name)}</name>');
  if (note != null && note.isNotEmpty) {
    b.writeln('    <desc>${_esc(note)}</desc>');
  }
  b.writeln('    <type>running</type>');
  for (final seg in track.segments) {
    b.writeln('    <trkseg>');
    for (final p in seg) {
      final at =
          startedAt.toUtc().add(Duration(milliseconds: (p.t * 1000).round()));
      b.write(
        '      <trkpt lat="${p.lat.toStringAsFixed(6)}" '
        'lon="${p.lon.toStringAsFixed(6)}">',
      );
      if (p.ele != null) b.write('<ele>${p.ele!.toStringAsFixed(1)}</ele>');
      b.writeln('<time>${at.toIso8601String()}</time></trkpt>');
    }
    b.writeln('    </trkseg>');
  }
  b
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return b.toString();
}

/// A file name for the export: "FITOS 2026-10-27 Morning run.gpx".
String gpxFileName(String name, DateTime startedLocal) {
  final date = startedLocal.toIso8601String().substring(0, 10);
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
  return 'FITOS $date ${safe.isEmpty ? 'run' : safe}.gpx';
}
