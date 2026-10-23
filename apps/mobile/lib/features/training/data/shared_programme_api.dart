import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/program.dart';

/// Beta 3.3 (ADR-034): a programme shared as a code. Structure only — the
/// server never sends weights or who shared it.
class SharedExercise {
  const SharedExercise({
    required this.name,
    required this.setCount,
    required this.repMin,
    required this.repMax,
    required this.missingEquipment,
  });

  factory SharedExercise.fromJson(Map<String, dynamic> j) => SharedExercise(
        name: j['name'] as String,
        setCount: j['setCount'] as int,
        repMin: j['repMin'] as int,
        repMax: j['repMax'] as int,
        missingEquipment:
            (j['missingEquipment'] as List<dynamic>).cast<String>(),
      );

  final String name;
  final int setCount;
  final int repMin;
  final int repMax;

  /// Equipment this exercise needs that your setting lacks.
  final List<String> missingEquipment;

  /// "3 × 6–8", or "3 × 8".
  String get prescription =>
      '$setCount × ${repMin == repMax ? '$repMin' : '$repMin–$repMax'}';
}

class SharedDay {
  const SharedDay({
    required this.dayOfWeek,
    required this.sessionName,
    required this.isRest,
    required this.exercises,
  });

  factory SharedDay.fromJson(Map<String, dynamic> j) => SharedDay(
        dayOfWeek: j['dayOfWeek'] as int,
        sessionName: j['sessionName'] as String,
        isRest: j['isRest'] as bool,
        exercises: [
          for (final x in j['exercises'] as List<dynamic>)
            SharedExercise.fromJson(x as Map<String, dynamic>),
        ],
      );

  final int dayOfWeek;
  final String sessionName;
  final bool isRest;
  final List<SharedExercise> exercises;
}

class SharedProgramme {
  const SharedProgramme({
    required this.code,
    required this.name,
    required this.daysPerWeek,
    required this.days,
  });

  factory SharedProgramme.fromJson(Map<String, dynamic> j) => SharedProgramme(
        code: j['code'] as String,
        name: j['name'] as String,
        daysPerWeek: j['daysPerWeek'] as int,
        days: [
          for (final d in j['days'] as List<dynamic>)
            SharedDay.fromJson(d as Map<String, dynamic>),
        ],
      );

  final String code;
  final String name;
  final int daysPerWeek;
  final List<SharedDay> days;
}

/// A code you made.
class MyShare {
  const MyShare({required this.code, required this.name, required this.url});

  factory MyShare.fromJson(Map<String, dynamic> j) => MyShare(
        code: j['code'] as String,
        name: j['name'] as String,
        url: j['url'] as String,
      );

  final String code;
  final String name;
  final String url;

  /// What the share sheet sends.
  String get message =>
      'Try my FITOS programme "$name": code ${displayShareCode(code)} · $url';
}

/// "K7Q2XM" → "FIT-K7Q2XM".
String displayShareCode(String code) => 'FIT-$code';

/// The 6-character code inside whatever was typed or pasted: "fit-k7q2xm",
/// "K7Q2XM", or the whole link. Null when there is none.
String? parseShareCode(String input) {
  var s = input.trim().toUpperCase();
  final slash = s.lastIndexOf('/P/');
  if (slash >= 0) s = s.substring(slash + 3);
  s = s.replaceAll(RegExp('[^A-Z0-9]'), '');
  if (s.startsWith('FIT') && s.length == 9) s = s.substring(3);
  return RegExp(r'^[2-9A-HJKMNP-Z]{6}$').hasMatch(s) ? s : null;
}

abstract class SharedProgrammeApi {
  Future<Result<MyShare>> share();
  Future<Result<SharedProgramme>> preview(String code);
  Future<Result<Program>> use(String code);
}

class DioSharedProgrammeApi implements SharedProgrammeApi {
  DioSharedProgrammeApi(this._dio);

  final Dio _dio;

  Future<Result<T>> _guard<T>(
    Future<Response<Map<String, dynamic>>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final r = await call();
      return Ok(parse(r.data!));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }

  @override
  Future<Result<MyShare>> share() => _guard(
        () => _dio.post<Map<String, dynamic>>('/v1/training/program/share'),
        MyShare.fromJson,
      );

  @override
  Future<Result<SharedProgramme>> preview(String code) => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/training/shared/$code'),
        SharedProgramme.fromJson,
      );

  @override
  Future<Result<Program>> use(String code) => _guard(
        () => _dio.post<Map<String, dynamic>>('/v1/training/shared/$code/use'),
        Program.fromJson,
      );
}

/// The phone's share sheet, behind a seam for tests.
abstract class TextSharer {
  Future<void> share(String text);
}

class SystemTextSharer implements TextSharer {
  @override
  Future<void> share(String text) =>
      SharePlus.instance.share(ShareParams(text: text));
}
