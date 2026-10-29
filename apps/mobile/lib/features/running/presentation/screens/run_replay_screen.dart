import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../domain/replay.dart';
import '../../domain/run.dart';
import '../../domain/track.dart';
import '../../domain/units.dart';
import '../controllers/running_providers.dart';
import '../widgets/route_painter.dart';
import '../widgets/run_map.dart';
import '../widgets/run_widgets.dart';

/// Beta 4.4 (owner 2026-10-29): a run told again. The route draws itself in
/// its pace colours with a moving dot, in about [kReplaySeconds] whatever
/// the run's length; play/pause, a scrubber, ½× and 2×. The time, distance
/// and pace at that moment of the run. From the phone's own copy of the
/// track: nothing is sent.
const kReplaySeconds = 20;

class RunReplayScreen extends ConsumerWidget {
  const RunReplayScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(runDetailProvider(id)).value;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text(run?.summary.name ?? 'Replay'),
      ),
      body: FitBackdrop(
        child: run == null || run.track == null
            ? const Center(child: CircularProgressIndicator())
            : _Replay(run: run, unit: ref.watch(runSettingsProvider).unit),
      ),
    );
  }
}

class _Replay extends StatefulWidget {
  const _Replay({required this.run, required this.unit});

  final RunDetail run;
  final DistanceUnit unit;

  @override
  State<_Replay> createState() => _ReplayState();
}

class _ReplayState extends State<_Replay> with SingleTickerProviderStateMixin {
  late final ReplayTimeline _timeline = ReplayTimeline(widget.run.track!);
  late final List<PaceStretch> _pace = paceStretches(widget.run.track!);
  late final List<List<(double, double)>> _whole = [
    for (final s in widget.run.track!.segments)
      [for (final p in s) (p.lat, p.lon)],
  ];
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: kReplaySeconds),
  )..addListener(_tick);
  double _speed = 1;

  /// The map is redrawn about ten times a second; the numbers every frame.
  int _lastDrawn = -1;
  List<List<(double, double)>> _drawn = const [];

  @override
  void initState() {
    super.initState();
    _clock.forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _tick() {
    final step = (_clock.value * kReplaySeconds * 10).floor();
    if (step != _lastDrawn) {
      _lastDrawn = step;
      _drawn = _timeline.routeTo(_clock.value);
    }
    setState(() {});
  }

  void _toggle() {
    if (_clock.isAnimating) {
      _clock.stop();
    } else {
      if (_clock.value >= 1) _clock.value = 0;
      _clock.forward();
    }
    setState(() {});
  }

  void _setSpeed(double speed) {
    _speed = speed;
    _clock.duration =
        Duration(milliseconds: (kReplaySeconds * 1000 / speed).round());
    if (_clock.isAnimating) _clock.forward();
    setState(() {});
  }

  /// The pace-coloured stretches up to the dot.
  List<(List<(double, double)>, Color)> _colouredTo(double d) {
    final out = <(List<(double, double)>, Color)>[];
    var walked = 0.0;
    for (final p in _pace) {
      if (walked >= d) break;
      out.add((p.points, paceColour(p.relative)));
      walked += _length(p.points);
    }
    return out;
  }

  final Map<List<(double, double)>, double> _lengths = {};
  double _length(List<(double, double)> pts) => _lengths.putIfAbsent(pts, () {
        var m = 0.0;
        for (var i = 1; i < pts.length; i++) {
          m += haversine(
            (lat: pts[i - 1].$1, lon: pts[i - 1].$2),
            (lat: pts[i].$1, lon: pts[i].$2),
          );
        }
        return m;
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final unit = widget.unit;
    if (_timeline.isEmpty) {
      return Center(
        child: Text('This run is too short to replay.', style: t.bodyLarge),
      );
    }
    final m = _timeline.at(_clock.value);
    final playing = _clock.isAnimating;
    return ListView(
      key: const ValueKey('replay.list'),
      padding: const EdgeInsets.all(FitSpacing.screen),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(fitGlass ? 18 : 0),
          child: SizedBox(
            height: 340,
            child: RunMap(
              key: const ValueKey('replay.map'),
              segments: _drawn.isEmpty ? _timeline.routeTo(0) : _drawn,
              frame: _whole,
              coloured: _pace.isEmpty ? null : _colouredTo(m.distanceM),
              position: m.position,
              interactive: false,
            ),
          ),
        ),
        const SizedBox(height: FitSpacing.xs),
        if (_pace.isNotEmpty) const PaceLegend(),
        const SizedBox(height: FitSpacing.md),
        FitBlock(
          padding: const EdgeInsets.all(FitSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: RunStat(
                  value: formatDuration(m.seconds.round()),
                  label: 'Time',
                  valueKey: const ValueKey('replay.time'),
                ),
              ),
              Expanded(
                child: RunStat(
                  value: formatDistance(m.distanceM, unit),
                  label: unit.label,
                  valueKey: const ValueKey('replay.distance'),
                ),
              ),
              Expanded(
                child: RunStat(
                  value: formatPace(m.paceSecPerKm, unit),
                  label: 'Pace ${unit.paceLabel}',
                  valueKey: const ValueKey('replay.pace'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: FitSpacing.sm),
        Slider(
          key: const ValueKey('replay.scrub'),
          value: _clock.value,
          onChanged: (v) {
            _clock.stop();
            _clock.value = v;
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final s in const [0.5, 1.0, 2.0])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  key: ValueKey('replay.speed.$s'),
                  label: Text(s == 0.5 ? '½×' : '${s.toInt()}×'),
                  selected: _speed == s,
                  onSelected: (_) => _setSpeed(s),
                ),
              ),
            const SizedBox(width: FitSpacing.md),
            IconButton.filled(
              key: const ValueKey('replay.play'),
              iconSize: 32,
              tooltip: playing ? 'Pause' : 'Play',
              onPressed: _toggle,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
          ],
        ),
      ],
    );
  }
}
