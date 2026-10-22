import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// Phase 19 (ADR-026): what a tester can say it is about. The server's
/// FEEDBACK_CATEGORIES, in the same order.
enum FeedbackCategory {
  bug('bug', 'Something broke'),
  idea('idea', 'An idea'),
  food('food', 'Food or mess'),
  training('training', 'Training'),
  other('other', 'Something else');

  const FeedbackCategory(this.wire, this.label);
  final String wire;
  final String label;
}

/// The server's FEEDBACK_MAX_LENGTH.
const kFeedbackMaxLength = 2000;

/// `POST /v1/feedback`.
abstract class FeedbackApi {
  Future<Result<void>> send({
    required FeedbackCategory category,
    required String message,
    required String appVersion,
  });
}

class DioFeedbackApi implements FeedbackApi {
  DioFeedbackApi(this._dio);

  final Dio _dio;

  /// Wire encoder, public for the conformance test.
  static Map<String, dynamic> requestJson({
    required FeedbackCategory category,
    required String message,
    required String appVersion,
  }) =>
      {'category': category.wire, 'message': message, 'appVersion': appVersion};

  @override
  Future<Result<void>> send({
    required FeedbackCategory category,
    required String message,
    required String appVersion,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/feedback',
        data: requestJson(
          category: category,
          message: message,
          appVersion: appVersion,
        ),
      );
      return const Ok(null);
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }
}
