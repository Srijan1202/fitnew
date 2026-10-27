/**
 * Running (beta 4.0, ADR-038): a run's GPS track and its wire encoding.
 *
 * The phone filters and smooths the raw GPS fixes before it stores them
 * (accuracy, jumps, standing drift): what it stores is the track, and both
 * the phone's live numbers and the server's record are computed from exactly
 * these points. Coordinates are kept to 6 decimals (about 0.1 m), elevation
 * to 0.1 m and time to 0.1 s, so the encoding loses nothing either side uses.
 *
 * Encoding `v: 1`: every point is four integers — lat·1e6, lon·1e6,
 * elevation·10 (decimetres) and t·10 (deciseconds since the start) — each
 * written as the difference from the previous point in Google's polyline
 * scheme (zig-zag, 5-bit groups, offset 63). A pause starts a new segment:
 * `breaks` holds the index of each segment's first point after the first.
 * Without elevation every elevation is written as 0 and read back as null.
 */

/** One stored point. */
export interface TrackPoint {
  /** Seconds since the run started (0.1 s steps). Strictly increasing. */
  readonly t: number;
  readonly lat: number;
  readonly lon: number;
  /** Metres above the ellipsoid (0.1 m steps); null when the phone had none. */
  readonly ele: number | null;
}

/** The points of a run, split at every pause (manual or auto-pause). */
export interface Track {
  readonly segments: readonly (readonly TrackPoint[])[];
}

/** The wire form (contracts `runTrackSchema`). */
export interface EncodedTrack {
  readonly v: 1;
  readonly points: string;
  readonly breaks: readonly number[];
  readonly elevation: boolean;
}

/** A run is at most this many points (14 h at one a second). */
export const MAX_TRACK_POINTS = 50_000;

const SCALE = { latLon: 1e6, ele: 10, t: 10 } as const;

export class TrackError extends Error {
  override readonly name = 'TrackError';
}

function writeValue(value: number, out: string[]): void {
  let v = value < 0 ? ~(value << 1) : value << 1;
  while (v >= 0x20) {
    out.push(String.fromCharCode((0x20 | (v & 0x1f)) + 63));
    v >>>= 5;
  }
  out.push(String.fromCharCode(v + 63));
}

/** Rounds a point to what the encoding keeps (the phone stores it this way). */
export function quantize(p: TrackPoint): TrackPoint {
  return {
    t: Math.round(p.t * SCALE.t) / SCALE.t,
    lat: Math.round(p.lat * SCALE.latLon) / SCALE.latLon,
    lon: Math.round(p.lon * SCALE.latLon) / SCALE.latLon,
    ele: p.ele === null ? null : Math.round(p.ele * SCALE.ele) / SCALE.ele,
  };
}

/** Encodes a track; empty segments are dropped. */
export function encodeTrack(track: Track): EncodedTrack {
  const out: string[] = [];
  const breaks: number[] = [];
  const all = track.segments.filter((s) => s.length > 0);
  const elevation = all.some((s) => s.some((p) => p.ele !== null));
  // A point without elevation in a track that has some keeps the last one
  // known (the first known, before any).
  let ele = all.flat().find((p) => p.ele !== null)?.ele ?? 0;
  let prev = [0, 0, 0, 0];
  let index = 0;
  all.forEach((segment, si) => {
    if (si > 0) breaks.push(index);
    for (const p of segment) {
      if (p.ele !== null) ele = p.ele;
      const cur = [
        Math.round(p.lat * SCALE.latLon),
        Math.round(p.lon * SCALE.latLon),
        elevation ? Math.round(ele * SCALE.ele) : 0,
        Math.round(p.t * SCALE.t),
      ];
      for (let k = 0; k < 4; k++) writeValue(cur[k]! - prev[k]!, out);
      prev = cur;
      index++;
    }
  });
  return { v: 1, points: out.join(''), breaks, elevation };
}

/**
 * Decodes and checks a track: whole points, coordinates on the globe, time
 * strictly increasing, breaks inside the track and increasing. Anything else
 * throws [TrackError] — a refusal, never a guess.
 */
export function decodeTrack(encoded: EncodedTrack): Track {
  const values: number[] = [];
  const s = encoded.points;
  let i = 0;
  while (i < s.length) {
    let result = 0;
    let shift = 0;
    let byte: number;
    do {
      if (i >= s.length) throw new TrackError('The track ends in the middle of a value.');
      byte = s.charCodeAt(i++) - 63;
      if (byte < 0 || byte > 63) throw new TrackError('The track has a character outside the encoding.');
      if (shift > 25) throw new TrackError('The track has a value too large to be a point.');
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    values.push(result & 1 ? ~(result >>> 1) : result >>> 1);
  }
  if (values.length % 4 !== 0) throw new TrackError('The track does not hold whole points.');
  const count = values.length / 4;
  if (count > MAX_TRACK_POINTS) throw new TrackError(`A run holds at most ${MAX_TRACK_POINTS} points.`);

  const points: TrackPoint[] = [];
  const acc = [0, 0, 0, 0];
  for (let n = 0; n < count; n++) {
    for (let k = 0; k < 4; k++) acc[k]! += values[n * 4 + k]!;
    const [lat, lon, ele, t] = [acc[0]! / SCALE.latLon, acc[1]! / SCALE.latLon, acc[2]! / SCALE.ele, acc[3]! / SCALE.t];
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) throw new TrackError('A point is not on the globe.');
    if (t < 0) throw new TrackError('A point is timed before the start.');
    if (n > 0 && t <= points[n - 1]!.t) throw new TrackError('The points are not in time order.');
    points.push({ t, lat, lon, ele: encoded.elevation ? ele : null });
  }

  if (count === 0) {
    if (encoded.breaks.length > 0) throw new TrackError('A pause is outside the track.');
    return { segments: [] };
  }
  // Strictly increasing cuts: every break inside the track, none repeated.
  const cuts = [0, ...encoded.breaks, count];
  const segments: TrackPoint[][] = [];
  for (let k = 1; k < cuts.length; k++) {
    if (cuts[k]! <= cuts[k - 1]!) throw new TrackError('A pause is outside the track.');
    segments.push(points.slice(cuts[k - 1], cuts[k]));
  }
  return { segments };
}

/** The mean Earth radius (IUGG), metres. */
export const EARTH_RADIUS_M = 6_371_008.8;

/** Great-circle distance between two points, metres. */
export function haversine(a: { lat: number; lon: number }, b: { lat: number; lon: number }): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}
