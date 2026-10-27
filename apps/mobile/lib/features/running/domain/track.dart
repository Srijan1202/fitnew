import 'dart:math' as math;

/// Beta 4.0 (ADR-038): a run's GPS track and its wire encoding — the same
/// rules as packages/core `running/track.ts`, which the server uses. The
/// phone stores the filtered points rounded the way the encoding keeps them
/// (6 decimals, 0.1 m, 0.1 s), so its live numbers and the server's record
/// come from exactly the same points.
class TrackPoint {
  const TrackPoint({
    required this.t,
    required this.lat,
    required this.lon,
    this.ele,
  });

  /// Seconds since the run started (0.1 s steps). Strictly increasing.
  final double t;
  final double lat;
  final double lon;

  /// Metres; null when the phone gave no altitude.
  final double? ele;

  /// Rounded to what the encoding keeps.
  TrackPoint quantized() => TrackPoint(
        t: jsRound(t * 10) / 10,
        lat: jsRound(lat * 1e6) / 1e6,
        lon: jsRound(lon * 1e6) / 1e6,
        ele: ele == null ? null : jsRound(ele! * 10) / 10,
      );

  @override
  bool operator ==(Object other) =>
      other is TrackPoint &&
      other.t == t &&
      other.lat == lat &&
      other.lon == lon &&
      other.ele == ele;

  @override
  int get hashCode => Object.hash(t, lat, lon, ele);

  @override
  String toString() => 'TrackPoint($t, $lat, $lon, $ele)';
}

/// JavaScript's Math.round (half up, towards +∞), so both sides round alike.
int jsRound(double x) => (x + 0.5).floor();

/// The points of a run, split at every pause.
class Track {
  const Track(this.segments);

  final List<List<TrackPoint>> segments;

  bool get isEmpty => segments.every((s) => s.isEmpty);
}

/// The wire form (contracts `runTrackSchema`).
class EncodedTrack {
  const EncodedTrack({
    required this.points,
    required this.breaks,
    required this.elevation,
  });

  factory EncodedTrack.fromJson(Map<String, dynamic> j) => EncodedTrack(
        points: j['points'] as String,
        breaks: [for (final b in j['breaks'] as List) (b as num).toInt()],
        elevation: j['elevation'] as bool,
      );

  final String points;
  final List<int> breaks;
  final bool elevation;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'points': points,
        'breaks': breaks,
        'elevation': elevation,
      };
}

class TrackFormatException implements Exception {
  const TrackFormatException(this.message);
  final String message;

  @override
  String toString() => 'TrackFormatException: $message';
}

void _write(int value, StringBuffer out) {
  var v = value < 0 ? ~(value << 1) : value << 1;
  while (v >= 0x20) {
    out.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  out.writeCharCode(v + 63);
}

/// Encodes a track (encoding v1); empty segments are dropped. A point
/// without elevation in a track that has some keeps the last one known.
EncodedTrack encodeTrack(Track track) {
  final all = track.segments.where((s) => s.isNotEmpty).toList();
  final elevation = all.any((s) => s.any((p) => p.ele != null));
  var ele = all.expand((s) => s).map((p) => p.ele).firstWhere(
            (e) => e != null,
            orElse: () => 0,
          ) ??
      0;
  final out = StringBuffer();
  final breaks = <int>[];
  var prev = <int>[0, 0, 0, 0];
  var index = 0;
  for (var si = 0; si < all.length; si++) {
    if (si > 0) breaks.add(index);
    for (final p in all[si]) {
      if (p.ele != null) ele = p.ele!;
      final cur = <int>[
        jsRound(p.lat * 1e6),
        jsRound(p.lon * 1e6),
        elevation ? jsRound(ele * 10) : 0,
        jsRound(p.t * 10),
      ];
      for (var k = 0; k < 4; k++) {
        _write(cur[k] - prev[k], out);
      }
      prev = cur;
      index++;
    }
  }
  return EncodedTrack(
    points: out.toString(),
    breaks: breaks,
    elevation: elevation,
  );
}

/// Decodes a track the server sent. Throws [TrackFormatException] on
/// anything malformed (the server checked it already; this is a guard).
Track decodeTrack(EncodedTrack encoded) {
  final s = encoded.points;
  final values = <int>[];
  var i = 0;
  while (i < s.length) {
    var result = 0;
    var shift = 0;
    int byte;
    do {
      if (i >= s.length) {
        throw const TrackFormatException('cut short');
      }
      byte = s.codeUnitAt(i++) - 63;
      if (byte < 0 || byte > 63 || shift > 25) {
        throw const TrackFormatException('not a track');
      }
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    values.add((result & 1) != 0 ? ~(result >> 1) : result >> 1);
  }
  if (values.length % 4 != 0) {
    throw const TrackFormatException('not whole points');
  }
  final count = values.length ~/ 4;
  final points = <TrackPoint>[];
  final acc = <int>[0, 0, 0, 0];
  for (var n = 0; n < count; n++) {
    for (var k = 0; k < 4; k++) {
      acc[k] += values[n * 4 + k];
    }
    points.add(
      TrackPoint(
        lat: acc[0] / 1e6,
        lon: acc[1] / 1e6,
        ele: encoded.elevation ? acc[2] / 10 : null,
        t: acc[3] / 10,
      ),
    );
  }
  if (count == 0) return const Track([]);
  final cuts = <int>[0, ...encoded.breaks, count];
  final segments = <List<TrackPoint>>[];
  for (var k = 1; k < cuts.length; k++) {
    if (cuts[k] <= cuts[k - 1] || cuts[k] > count) {
      throw const TrackFormatException('a pause outside the track');
    }
    segments.add(points.sublist(cuts[k - 1], cuts[k]));
  }
  return Track(segments);
}

/// The mean Earth radius (IUGG), metres — the server's.
const double earthRadiusM = 6371008.8;

/// Great-circle distance, metres.
double haversine(
  ({double lat, double lon}) a,
  ({double lat, double lon}) b,
) {
  const rad = math.pi / 180;
  final dLat = (b.lat - a.lat) * rad;
  final dLon = (b.lon - a.lon) * rad;
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.lat * rad) *
          math.cos(b.lat * rad) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

/// [haversine] between two track points.
double distanceBetween(TrackPoint a, TrackPoint b) =>
    haversine((lat: a.lat, lon: a.lon), (lat: b.lat, lon: b.lon));
