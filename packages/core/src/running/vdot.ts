/**
 * Running (beta 4.1, ADR-039): fitness from a race, and the paces it gives —
 * Jack Daniels' published VDOT equations (Daniels & Gilbert, "Oxygen Power",
 * 1979), the ones his tables are built from.
 *
 *   VO2(v)   = −4.60 + 0.182258·v + 0.000104·v²            (ml/kg/min; v in m/min)
 *   %max(t)  = 0.8 + 0.1894393·e^(−0.012778·t) + 0.2989558·e^(−0.1932605·t)   (t in min)
 *   VDOT     = VO2(d / t) / %max(t)
 *
 * A race prediction solves VDOT·%max(t) = VO2(d / t) for t. Training paces
 * are the speeds at a share of VDOT: easy 62–74 %, threshold 88 %, interval
 * 97.5 %, repetition 106 %; marathon pace is the predicted marathon itself.
 */

/** The four race distances, metres. */
export const RACE_DISTANCES_M = { '5k': 5000, '10k': 10_000, half: 21_097.5, marathon: 42_195 } as const;
export type RaceDistance = keyof typeof RACE_DISTANCES_M;

/** VDOT is meaningful in this range (Daniels' tables run 30–85). */
export const VDOT_MIN = 20;
export const VDOT_MAX = 90;

/** Shares of VDOT for the training paces. */
export const ZONE_SHARE = { easySlow: 0.62, easyFast: 0.74, threshold: 0.88, interval: 0.975, repetition: 1.06 } as const;

/** Oxygen cost of running at `v` metres a minute (ml/kg/min). */
export function vo2At(v: number): number {
  return -4.6 + 0.182258 * v + 0.000104 * v * v;
}

/** The share of VO2max that can be held for `minutes`. */
export function sustainableShare(minutes: number): number {
  return 0.8 + 0.1894393 * Math.exp(-0.012778 * minutes) + 0.2989558 * Math.exp(-0.1932605 * minutes);
}

/** The speed (m/min) whose oxygen cost is `vo2` — the inverse of [vo2At]. */
export function speedFor(vo2: number): number {
  const a = 0.000104;
  const b = 0.182258;
  const c = -4.6 - vo2;
  return (-b + Math.sqrt(b * b - 4 * a * c)) / (2 * a);
}

const round1 = (x: number) => Math.round(x * 10) / 10;

/** VDOT from a race or time trial (1 decimal), clamped to [VDOT_MIN, VDOT_MAX]. */
export function vdotFromRace(distanceM: number, seconds: number): number {
  const minutes = seconds / 60;
  const v = vo2At(distanceM / minutes) / sustainableShare(minutes);
  return round1(Math.min(VDOT_MAX, Math.max(VDOT_MIN, v)));
}

/** Predicted race time for a distance at a VDOT, whole seconds (bisection; monotonic in t). */
export function predictSeconds(vdot: number, distanceM: number): number {
  // f(t) = VDOT·%max(t) − VO2(d/t): negative when t is too short, positive when too long.
  const f = (minutes: number) => vdot * sustainableShare(minutes) - vo2At(distanceM / minutes);
  let lo = 1;
  let hi = 2000;
  for (let i = 0; i < 80; i++) {
    const mid = (lo + hi) / 2;
    if (f(mid) < 0) lo = mid;
    else hi = mid;
  }
  return Math.round(((lo + hi) / 2) * 60);
}

/** Seconds per km at a share of VDOT. */
export function paceAt(vdot: number, share: number): number {
  return Math.round(60_000 / speedFor(vdot * share));
}

/** A pace range, seconds per km: `fast` is the lower number. */
export interface PaceRange {
  readonly fast: number;
  readonly slow: number;
}

export interface PaceZones {
  readonly vdot: number;
  readonly easy: PaceRange;
  readonly marathon: number;
  readonly threshold: number;
  readonly interval: number;
  readonly repetition: number;
}

export function zones(vdot: number): PaceZones {
  return {
    vdot,
    easy: { fast: paceAt(vdot, ZONE_SHARE.easyFast), slow: paceAt(vdot, ZONE_SHARE.easySlow) },
    marathon: Math.round(predictSeconds(vdot, RACE_DISTANCES_M.marathon) / (RACE_DISTANCES_M.marathon / 1000)),
    threshold: paceAt(vdot, ZONE_SHARE.threshold),
    interval: paceAt(vdot, ZONE_SHARE.interval),
    repetition: paceAt(vdot, ZONE_SHARE.repetition),
  };
}

/** The VDOT a goal time at a distance needs. */
export function vdotForGoal(distanceM: number, seconds: number): number {
  return vdotFromRace(distanceM, seconds);
}
