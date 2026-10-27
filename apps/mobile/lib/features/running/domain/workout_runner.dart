import 'dart:math' as math;

import 'workout.dart';

/// Beta 4.1 (ADR-039): walks a structured run through its steps as it
/// happens. A step ends after its distance (from the GPS track) or its time
/// (the run's active timer); the runner can also move on by hand. Each step
/// leaves a lap mark on the run's clock, which the server measures on the
/// track.
class WorkoutRunner {
  WorkoutRunner(this.workout);

  final RunWorkout workout;
  List<WorkoutStep> get steps => workout.steps;

  int _index = 0;
  double _startDistance = 0;
  int _startActive = 0;
  double _startT = 0;
  final List<LapMark> marks = [];

  int get index => _index;
  bool get done => _index >= steps.length;
  WorkoutStep? get current => done ? null : steps[_index];
  WorkoutStep? get next => _index + 1 < steps.length ? steps[_index + 1] : null;

  /// How far into the current step: metres or seconds, by its kind of end.
  ({double? metresLeft, int? secondsLeft}) left({
    required double distanceM,
    required int activeSeconds,
  }) {
    final s = current;
    if (s == null) return (metresLeft: null, secondsLeft: null);
    if (s.distanceM != null) {
      return (
        metresLeft: math.max(0, s.distanceM! - (distanceM - _startDistance)),
        secondsLeft: null,
      );
    }
    return (
      metresLeft: null,
      secondsLeft: math.max(0, s.seconds! - (activeSeconds - _startActive)),
    );
  }

  /// Moves on past every step that has ended; returns the steps begun (in
  /// order) so the coach can call them.
  List<int> update({
    required double distanceM,
    required int activeSeconds,
    required double clockT,
  }) {
    final begun = <int>[];
    while (!done) {
      final l = left(distanceM: distanceM, activeSeconds: activeSeconds);
      final ended = (l.metresLeft ?? l.secondsLeft ?? 1) <= 0;
      if (!ended) break;
      _advance(distanceM, activeSeconds, clockT);
      if (!done) begun.add(_index);
    }
    return begun;
  }

  /// The runner's "Next step".
  int? skip({
    required double distanceM,
    required int activeSeconds,
    required double clockT,
  }) {
    if (done) return null;
    _advance(distanceM, activeSeconds, clockT);
    return done ? null : _index;
  }

  void _advance(double distanceM, int activeSeconds, double clockT) {
    marks.add(LapMark(_index, _startT, math.max(_startT, clockT)));
    _index++;
    _startDistance = distanceM;
    _startActive = activeSeconds;
    _startT = clockT;
  }

  /// Closes the step in progress when the run finishes early.
  void finish(double clockT) {
    if (done) return;
    marks.add(LapMark(_index, _startT, math.max(_startT, clockT)));
    _index = steps.length;
  }

  /// Picks up a run that FITOS reopened mid-workout: the steps done stay done.
  void restore(
    List<LapMark> saved, {
    required double distanceM,
    required int activeSeconds,
    required double clockT,
  }) {
    marks
      ..clear()
      ..addAll(saved);
    _index = saved.isEmpty ? 0 : saved.last.step + 1;
    _startDistance = distanceM;
    _startActive = activeSeconds;
    _startT = saved.isEmpty ? 0 : clockT;
  }
}
