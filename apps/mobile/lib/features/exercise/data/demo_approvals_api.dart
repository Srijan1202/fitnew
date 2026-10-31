import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../domain/demo/demo_rig.dart';
import '../domain/demo/exercise_demos.dart';

/// Beta 5.2 (owner): an exercise demo shows only once an admin approved it
/// (`GET /v1/exercises/demo-approvals`, the admin panel's Exercise demos).
abstract class DemoApprovalsApi {
  Future<Result<Set<String>>> approved();
}

class DioDemoApprovalsApi implements DemoApprovalsApi {
  DioDemoApprovalsApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<Set<String>>> approved() async {
    try {
      final r =
          await _dio.get<Map<String, dynamic>>('/v1/exercises/demo-approvals');
      return Ok({
        for (final s in (r.data!['approved'] as List)) s as String,
      });
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }
}

final demoApprovalsApiProvider = Provider<DemoApprovalsApi>(
  (ref) => DioDemoApprovalsApi(ref.watch(dioProvider)),
);

const _cacheKey = 'exercise.demos.approved';

/// The approved demos: the server's list, kept on the phone so they show
/// offline; the last list when the server cannot be reached; none before
/// the first answer. Asked again whenever FITOS comes back.
final approvedDemosProvider = FutureProvider<Set<String>>((ref) async {
  if (ref.watch(sessionUserIdProvider) == null) return const {};
  // An approval in the admin panel shows when FITOS next comes back.
  final lifecycle = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(lifecycle.dispose);
  final result = await ref.watch(demoApprovalsApiProvider).approved();
  switch (result) {
    case Ok(:final value):
      unawaited(_save(value));
      return value;
    case Err():
      return _saved();
  }
});

Future<void> _save(Set<String> approved) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_cacheKey, approved.toList()..sort());
  } on Object {
    // Shown now; saved next time.
  }
}

Future<Set<String>> _saved() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList(_cacheKey)};
  } on Object {
    return const {};
  }
}

/// An exercise's demo, only when approved (a variant follows its demo).
final approvedDemoProvider =
    Provider.family<({Demo demo, String? note})?, String>((ref, slug) {
  final match = demoFor(slug);
  if (match == null) return null;
  final approved = ref.watch(approvedDemosProvider).value ?? const {};
  return approved.contains(demoSlugFor(slug)) ? match : null;
});
