import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/db/app_database.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/location_source.dart';
import '../../data/run_store.dart';
import '../../domain/gps_filter.dart';
import '../../domain/live_stats.dart';
import '../../domain/run.dart';
import '../../domain/track.dart';
import '../../domain/units.dart';
import 'running_providers.dart';

/// Beta 4.0 (ADR-038): the run being recorded.
///
/// The phone's database is the run's source of truth while it happens: the
/// row holds its state and timer, every stored point is written as it
/// arrives. If Android or a flat battery ends FITOS mid-run, the next start
/// finds the run paused at its last point — nothing recorded is lost.
enum RunStatus { recording, paused, autoPaused, finished }

enum GpsSignal { searching, weak, good, lost }

class LiveRun {
  LiveRun({
    required this.id,
    required this.kind,
    required this.goal,
    required this.status,
    required this.startedAt,
    required this.activeSeconds,
    required this.track,
    required this.gps,
    this.restored = false,
  })  : distanceM = track.distanceM,
        splitCount = track.splitSeconds.length;

  final String id;
  final RunKind kind;
  final RunGoal goal;
  final RunStatus status;
  final DateTime startedAt;
  final int activeSeconds;

  /// The live figures (distance, paces, splits, the line on the map).
  final LiveTrack track;
  final GpsSignal gps;

  /// Found after FITOS was closed during the run (shown once on the screen).
  final bool restored;

  /// The distance and completed splits when this state was made ([track]
  /// keeps growing; these do not), so a listener can see what changed.
  final double distanceM;
  final int splitCount;

  bool get isRunning => status == RunStatus.recording;

  /// Paused by the runner or by auto-pause.
  bool get isPaused =>
      status == RunStatus.paused || status == RunStatus.autoPaused;

  double? get avgPaceSecPerKm =>
      distanceM < 10 ? null : activeSeconds / (distanceM / 1000);

  /// 0–1 towards a distance or time goal; null otherwise.
  double? get progress => goalProgress(
        goalKind: goal.kind.name,
        goalValue: goal.value,
        distanceM: distanceM,
        activeSeconds: activeSeconds,
      );

  bool get goalReached => (progress ?? 0) >= 1;

  LiveRun copyWith({
    RunStatus? status,
    int? activeSeconds,
    GpsSignal? gps,
    bool? restored,
  }) =>
      LiveRun(
        id: id,
        kind: kind,
        goal: goal,
        status: status ?? this.status,
        startedAt: startedAt,
        activeSeconds: activeSeconds ?? this.activeSeconds,
        track: track,
        gps: gps ?? this.gps,
        restored: restored ?? this.restored,
      );
}

class RunRecorder extends Notifier<LiveRun?> {
  StreamSubscription<GpsFix>? _sub;
  Timer? _ticker;
  GpsFilter? _filter;
  final AutoPause _auto = AutoPause();
  int _seq = 0;
  int _segment = 0;
  int _activeMs = 0;
  DateTime? _resumedAt;
  DateTime? _lastFixAt;
  int _lastNotified = -100;
  bool _newSegment = false;
  Future<void> _writes = Future.value();

  RunStore get _store => ref.read(runningRepositoryProvider).store;
  DateTime _now() => ref.read(runClockProvider)();

  @override
  LiveRun? build() {
    // A new user starts with no run (sign-out clears the phone's rows).
    ref.watch(sessionUserIdProvider);
    ref.onDispose(_stopSensors);
    unawaited(Future.microtask(_restore));
    return null;
  }

  /* ------------------------------------------------------------ start -- */

  /// Asks for location (outdoor). The run starts only when it is granted.
  Future<LocationAccess> access() =>
      ref.read(locationSourceProvider).ensureAccess();

  Future<void> start({required RunKind kind, required RunGoal goal}) async {
    if (state != null) return;
    final now = _now();
    final id = const Uuid().v4();
    _activeMs = 0;
    _resumedAt = now;
    _seq = 0;
    _segment = 0;
    _newSegment = true;
    _auto.reset();
    await _store.insert(
      LocalRunsCompanion.insert(
        clientRunId: id,
        kind: kind.name,
        status: RunStatus.recording.name,
        goalKind: goal.kind.name,
        goalValue: Value(goal.value),
        startedAt: now.toUtc().toIso8601String(),
        resumedAt: Value(now.toUtc().toIso8601String()),
        updatedAt: now.toUtc().toIso8601String(),
      ),
    );
    state = LiveRun(
      id: id,
      kind: kind,
      goal: goal,
      status: RunStatus.recording,
      startedAt: now,
      activeSeconds: 0,
      track: _newTrack(),
      gps: kind == RunKind.outdoor ? GpsSignal.searching : GpsSignal.good,
    );
    _startSensors(now);
  }

  LiveTrack _newTrack() => LiveTrack(
        weightKg:
            ref.read(profileControllerProvider).value?.profile.latestWeightKg,
        splitUnitM: ref.read(runSettingsProvider).unit.metres,
      );

  void _startSensors(DateTime startedAt) {
    final run = state!;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (run.kind == RunKind.outdoor) {
      _filter = GpsFilter(startedAt: startedAt);
      _sub = ref.read(locationSourceProvider).fixes().listen(_onFix);
    }
  }

  void _stopSensors() {
    _ticker?.cancel();
    _ticker = null;
    unawaited(_sub?.cancel());
    _sub = null;
  }

  /* ---------------------------------------------------------- the run -- */

  int _activeSecondsAt(DateTime now) {
    final running =
        _resumedAt == null ? 0 : now.difference(_resumedAt!).inMilliseconds;
    return (_activeMs + (running < 0 ? 0 : running)) ~/ 1000;
  }

  void _tick() {
    final run = state;
    if (run == null) return;
    final now = _now();
    var gps = run.gps;
    if (run.kind == RunKind.outdoor &&
        _lastFixAt != null &&
        now.difference(_lastFixAt!) > const Duration(seconds: 10)) {
      gps = GpsSignal.lost;
    }
    state = run.copyWith(activeSeconds: _activeSecondsAt(now), gps: gps);
    if (state!.activeSeconds - _lastNotified >= 10) unawaited(_notify());
  }

  void _onFix(GpsFix fix) {
    final run = state;
    final filter = _filter;
    if (run == null || filter == null || run.status == RunStatus.finished) {
      return;
    }
    _lastFixAt = _now();
    final gps = fix.accuracyM <= 10 ? GpsSignal.good : GpsSignal.weak;
    final result = filter.add(fix);

    // Auto-pause: only while moving or auto-paused (a runner's pause is theirs).
    if (ref.read(runSettingsProvider).autoPause &&
        run.status != RunStatus.paused &&
        _auto.add(fix.at, result.speedMs)) {
      if (_auto.paused) {
        _pauseAt(_now(), RunStatus.autoPaused);
      } else {
        _resumeAt(_now());
      }
    }

    final point = result.point;
    if (point != null && state!.status == RunStatus.recording) {
      final seg = _segment;
      final seq = _seq++;
      final fresh = _newSegment;
      _newSegment = false;
      state!.track.add(point, newSegment: fresh);
      _write(() => _store.addPoints(run.id, seq, seg, [point]));
    }
    state = state!.copyWith(
      gps: gps,
      activeSeconds: _activeSecondsAt(_now()),
    );
  }

  /// Serialises the database writes of one run, in order.
  void _write(Future<void> Function() write) {
    _writes = _writes.then((_) => write()).catchError((Object _) {});
  }

  void _pauseAt(DateTime now, RunStatus status) {
    final run = state;
    if (run == null || run.status != RunStatus.recording) {
      if (run != null && run.isPaused && status != run.status) {
        state = run.copyWith(status: status);
      }
      return;
    }
    _activeMs += now.difference(_resumedAt!).inMilliseconds;
    _resumedAt = null;
    _segment++;
    _newSegment = true;
    _filter?.newSegment();
    state = run.copyWith(status: status, activeSeconds: _activeSecondsAt(now));
    _persist(status);
    unawaited(_notify());
  }

  void _resumeAt(DateTime now) {
    final run = state;
    if (run == null || !run.isPaused) return;
    _resumedAt = now;
    _auto.reset();
    state = run.copyWith(status: RunStatus.recording, restored: false);
    _persist(RunStatus.recording);
    unawaited(_notify());
  }

  void _persist(RunStatus status, {DateTime? endedAt}) {
    final run = state;
    if (run == null) return;
    final now = _now().toUtc().toIso8601String();
    _write(
      () => _store.update(
        run.id,
        LocalRunsCompanion(
          status: Value(status.name),
          activeMs: Value(_activeMs),
          resumedAt: Value(_resumedAt?.toUtc().toIso8601String()),
          segment: Value(_segment),
          endedAt: endedAt == null
              ? const Value.absent()
              : Value(endedAt.toUtc().toIso8601String()),
          updatedAt: Value(now),
        ),
      ),
    );
  }

  /// The runner's pause.
  void pause() => _pauseAt(_now(), RunStatus.paused);

  void resume() {
    if (state?.kind == RunKind.outdoor && _sub == null) {
      // After a restore the sensors are off until the runner resumes.
      _filter = GpsFilter(startedAt: state!.startedAt);
      _sub = ref.read(locationSourceProvider).fixes().listen(_onFix);
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _resumeAt(_now());
  }

  /// Stops the run; it waits for Save or Discard on the summary.
  Future<void> finish() async {
    final run = state;
    if (run == null || run.status == RunStatus.finished) return;
    final now = _now();
    if (_resumedAt != null) {
      _activeMs += now.difference(_resumedAt!).inMilliseconds;
      _resumedAt = null;
    }
    _stopSensors();
    state = run.copyWith(
      status: RunStatus.finished,
      activeSeconds: _activeSecondsAt(now),
    );
    _persist(RunStatus.finished, endedAt: now);
    await _writes;
  }

  /// Throws the run away: nothing is kept.
  Future<void> discard() async {
    final run = state;
    if (run == null) return;
    _stopSensors();
    state = null;
    await _writes;
    await _store.delete(run.id);
  }

  /// Saves the finished run (queued for the server) and clears the recorder.
  Future<String?> save({
    required String name,
    String? note,
    int? effort,
    double? treadmillDistanceM,
  }) async {
    final run = state;
    if (run == null) return null;
    if (run.status != RunStatus.finished) await finish();
    await _writes;
    await ref.read(runningRepositoryProvider).save(
          run.id,
          name: name,
          note: note,
          effort: effort,
          treadmillDistanceM: treadmillDistanceM,
        );
    state = null;
    return run.id;
  }

  /// Waits for every point and state change to reach the database (tests).
  Future<void> flush() => _writes;

  /* ------------------------------------------------------ notification -- */

  Future<void> _notify() async {
    final run = state;
    if (run == null || run.kind != RunKind.outdoor) return;
    _lastNotified = run.activeSeconds;
    final unit = ref.read(runSettingsProvider).unit;
    final distance =
        '${formatDistance(run.track.distanceM, unit)} ${unit.label}';
    final pace = '${formatPace(run.avgPaceSecPerKm, unit)} ${unit.paceLabel}';
    if (run.status == RunStatus.finished) return;
    await ref.read(runNotificationProvider).show(
          title: run.isRunning ? 'Run in progress' : 'Run paused',
          body: run.isRunning
              ? '$distance · avg $pace'
              : '${formatDuration(run.activeSeconds)} · $distance',
          runningSince: run.isRunning
              ? _now().subtract(Duration(seconds: run.activeSeconds))
              : null,
        );
  }

  /* ----------------------------------------------------------- restore -- */

  Future<void> _restore() async {
    LocalRun? row;
    try {
      row = await _store.current();
    } on Object {
      return;
    }
    if (row == null || !ref.mounted || state != null) return;
    final kind = RunKind.parse(row.kind);
    final stored = await _store.track(row.clientRunId);
    final startedAt = DateTime.parse(row.startedAt);
    final live = _newTrack();
    for (final seg in stored.segments) {
      for (var i = 0; i < seg.length; i++) {
        live.add(seg[i], newSegment: i == 0);
      }
    }
    _seq = await _store.pointCount(row.clientRunId);
    _segment = row.segment;
    _activeMs = row.activeMs;
    var status = RunStatus.values.byName(row.status);
    if (status == RunStatus.recording || status == RunStatus.autoPaused) {
      // FITOS was closed while recording: count the time up to the last
      // point, and wait paused for the runner.
      if (status == RunStatus.recording && row.resumedAt != null) {
        final resumed = DateTime.parse(row.resumedAt!);
        final last = stored.isEmpty
            ? resumed
            : startedAt.add(
                Duration(
                  milliseconds: (stored.segments.last.last.t * 1000).round(),
                ),
              );
        final ms = last.difference(resumed).inMilliseconds;
        if (ms > 0) _activeMs += ms;
      }
      status = RunStatus.paused;
      _segment++;
    }
    _resumedAt = null;
    _newSegment = true;
    if (!ref.mounted) return;
    state = LiveRun(
      id: row.clientRunId,
      kind: kind,
      goal: RunGoal(RunGoalKind.parse(row.goalKind), row.goalValue),
      status: status,
      startedAt: startedAt,
      activeSeconds: _activeMs ~/ 1000,
      track: live,
      gps: GpsSignal.searching,
      restored: status != RunStatus.finished,
    );
    if (status == RunStatus.paused) _persist(status);
  }
}

final runRecorderProvider =
    NotifierProvider<RunRecorder, LiveRun?>(RunRecorder.new);

/// Points in the run being recorded, for the map (the same lists).
List<List<TrackPoint>> livePolyline(LiveRun run) => run.track.segments;
