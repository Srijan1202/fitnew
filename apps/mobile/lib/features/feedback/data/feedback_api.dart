import 'dart:convert';
import 'dart:typed_data';

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

  static FeedbackCategory of(String wire) =>
      values.firstWhere((c) => c.wire == wire, orElse: () => other);
}

/// The server's FEEDBACK_MAX_LENGTH.
const kFeedbackMaxLength = 2000;

/// Beta 3.6: the server's FEEDBACK_MAX_PICTURES and _MAX_BYTES.
const kFeedbackMaxPictures = 3;
const kFeedbackPictureMaxBytes = 1000000;

/// The picture's type from its first bytes (what the server checks too);
/// null for one the server does not take (e.g. HEIC).
String? feedbackPictureType(Uint8List b) {
  if (b.length > 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) {
    return 'image/jpeg';
  }
  if (b.length > 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4e &&
      b[3] == 0x47) {
    return 'image/png';
  }
  if (b.length > 12 &&
      ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

/// Beta 3.6: the phone, sent when the person leaves it in.
class FeedbackDevice {
  const FeedbackDevice({required this.model, required this.os, this.screen});

  /// e.g. "Samsung SM-S921B".
  final String model;

  /// e.g. "Android 15".
  final String os;

  /// The screen feedback was opened from, e.g. "/plan/session".
  final String? screen;

  Map<String, dynamic> toJson() => {'model': model, 'os': os, 'screen': screen};

  /// "Samsung SM-S921B · Android 15".
  String get label => '$model · $os';
}

/// A reply from the FITOS team.
class FeedbackReply {
  const FeedbackReply({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.readAt,
  });

  factory FeedbackReply.fromJson(Map<String, dynamic> j) => FeedbackReply(
        id: j['id'] as String,
        message: j['message'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        readAt:
            j['readAt'] == null ? null : DateTime.parse(j['readAt'] as String),
      );

  final String id;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;
}

/// One of the person's own messages.
class MyFeedback {
  const MyFeedback({
    required this.id,
    required this.category,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.pictures,
    required this.replies,
  });

  factory MyFeedback.fromJson(Map<String, dynamic> j) => MyFeedback(
        id: j['id'] as String,
        category: FeedbackCategory.of(j['category'] as String),
        message: j['message'] as String,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        pictures: j['pictures'] as int,
        replies: [
          for (final r in j['replies'] as List<dynamic>)
            FeedbackReply.fromJson(r as Map<String, dynamic>),
        ],
      );

  final String id;
  final FeedbackCategory category;
  final String message;

  /// new, read or done (the admin's).
  final String status;
  final DateTime createdAt;
  final int pictures;
  final List<FeedbackReply> replies;

  /// What the sender sees for the status.
  String get statusLabel => switch (status) {
        'done' => 'Done',
        'read' => 'Seen',
        _ => 'Received',
      };
}

/// `GET /v1/feedback/mine`.
class MyFeedbackList {
  const MyFeedbackList({required this.items, required this.unread});

  factory MyFeedbackList.fromJson(Map<String, dynamic> j) => MyFeedbackList(
        items: [
          for (final x in j['items'] as List<dynamic>)
            MyFeedback.fromJson(x as Map<String, dynamic>),
        ],
        unread: j['unread'] as int,
      );

  final List<MyFeedback> items;
  final int unread;
}

/// `POST /v1/feedback`; beta 3.6: the person's messages and the replies.
abstract class FeedbackApi {
  Future<Result<void>> send({
    required FeedbackCategory category,
    required String message,
    required String appVersion,
    FeedbackDevice? device,
    List<Uint8List> pictures = const [],
  });

  Future<Result<MyFeedbackList>> mine();

  /// Every reply is now read.
  Future<Result<void>> markRead();
}

class DioFeedbackApi implements FeedbackApi {
  DioFeedbackApi(this._dio);

  final Dio _dio;

  /// Wire encoder, public for the conformance test.
  static Map<String, dynamic> requestJson({
    required FeedbackCategory category,
    required String message,
    required String appVersion,
    FeedbackDevice? device,
    List<Uint8List> pictures = const [],
  }) =>
      {
        'category': category.wire,
        'message': message,
        'appVersion': appVersion,
        'device': device?.toJson(),
        'pictures': [
          for (final p in pictures)
            {
              'type': feedbackPictureType(p) ?? 'image/jpeg',
              'data': base64Encode(p),
            },
        ],
      };

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Ok(await call());
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }

  @override
  Future<Result<void>> send({
    required FeedbackCategory category,
    required String message,
    required String appVersion,
    FeedbackDevice? device,
    List<Uint8List> pictures = const [],
  }) =>
      _guard(() async {
        await _dio.post<Map<String, dynamic>>(
          '/v1/feedback',
          data: requestJson(
            category: category,
            message: message,
            appVersion: appVersion,
            device: device,
            pictures: pictures,
          ),
        );
      });

  @override
  Future<Result<MyFeedbackList>> mine() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/v1/feedback/mine');
        return MyFeedbackList.fromJson(r.data!);
      });

  @override
  Future<Result<void>> markRead() => _guard(() async {
        await _dio.post<Map<String, dynamic>>('/v1/feedback/mine/read');
      });
}
