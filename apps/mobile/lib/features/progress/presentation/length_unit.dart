import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Beta 4.1.1 (owner): tape measurements in centimetres or inches. Only how
/// they are shown and typed: the server keeps centimetres, so changing the
/// unit never changes a reading.
enum LengthUnit {
  cm('cm'),
  inch('in');

  const LengthUnit(this.label);
  final String label;

  static const cmPerInch = 2.54;

  static LengthUnit parse(String? s) =>
      s == LengthUnit.inch.name ? LengthUnit.inch : LengthUnit.cm;

  /// A reading in centimetres, in this unit.
  double fromCm(double cm) => this == LengthUnit.cm ? cm : cm / cmPerInch;

  /// What was typed in this unit, in centimetres (what the server keeps).
  double toCm(double value) =>
      this == LengthUnit.cm ? value : value * cmPerInch;

  /// "81.5" — one decimal at most, none when whole.
  String number(double cm) {
    final v = (fromCm(cm) * 10).round() / 10;
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }
}

/// Kept on the phone; centimetres unless changed.
class LengthUnitController extends Notifier<LengthUnit> {
  static const _key = 'progress.lengthUnit';

  /// Set once the user changes it: a late load must not undo it.
  bool _changed = false;

  @override
  LengthUnit build() {
    unawaited(_load());
    return LengthUnit.cm;
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!ref.mounted || _changed) return;
      state = LengthUnit.parse(p.getString(_key));
    } on Object {
      // Centimetres stand.
    }
  }

  Future<void> set(LengthUnit unit) async {
    _changed = true;
    state = unit;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, unit.name);
    } on Object {
      // Kept for this session only.
    }
  }
}

final lengthUnitProvider = NotifierProvider<LengthUnitController, LengthUnit>(
  LengthUnitController.new,
);

/// The cm | in switch, wherever measurements are shown or typed.
class LengthUnitSwitch extends ConsumerWidget {
  const LengthUnitSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(lengthUnitProvider);
    return SegmentedButton<LengthUnit>(
      key: const ValueKey('length.unit'),
      // The app's switch size and corners (owner 2026-10-30: the compact
      // one looked rounder than the rest and crowded the tiles).
      showSelectedIcon: false,
      segments: [
        for (final u in LengthUnit.values)
          ButtonSegment(
            value: u,
            label: Text(u.label, key: ValueKey('length.unit.${u.name}')),
          ),
      ],
      selected: {unit},
      onSelectionChanged: (s) =>
          ref.read(lengthUnitProvider.notifier).set(s.single),
    );
  }
}
