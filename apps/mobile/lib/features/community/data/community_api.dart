import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/community.dart';

/// Beta 5.8 (ADR-057): `/v1/community/...` — joining and leaving, people,
/// friends, blocks, clubs, the boards and reports.
abstract class CommunityApi {
  Future<Result<CommunityMe>> me();
  Future<Result<CommunityMe>> join({
    required String handle,
    required String? country,
    required bool onWorld,
    required String policyVersion,
  });
  Future<Result<CommunityMe>> update({
    String? handle,
    String? country,
    bool clearCountry = false,
    bool? onWorld,
  });
  Future<Result<void>> leave();

  Future<Result<List<CommunityPerson>>> search(String q);
  Future<Result<FriendLists>> friends();

  /// 'requested', or 'friends' when they had asked you first.
  Future<Result<String>> addFriend(String handle);
  Future<Result<void>> accept(String userId);

  /// Decline, cancel or unfriend.
  Future<Result<void>> unfriend(String userId);
  Future<Result<List<CommunityPerson>>> blocked();
  Future<Result<void>> block(String userId);
  Future<Result<void>> unblock(String userId);

  Future<Result<List<Club>>> clubs();
  Future<Result<Club>> createClub(String name);
  Future<Result<Club>> joinClub(String code);
  Future<Result<void>> leaveClub(String clubId);

  /// Beta 6.2 (C4): a friend's or club-mate's board data.
  Future<Result<PersonProfile>> personProfile(String userId);

  /// Beta 6.2 (C5): the owner's tools.
  Future<Result<Club>> renameClub(String clubId, String name);
  Future<Result<Club>> newClubCode(String clubId);
  Future<Result<Club>> passClub(String clubId, String userId);
  Future<Result<void>> removeMember(String clubId, String userId);
  Future<Result<List<CommunityPerson>>> removedFrom(String clubId);
  Future<Result<void>> letBack(String clubId, String userId);

  Future<Result<Board>> friendsBoard(BoardMetric metric);
  Future<Result<Board>> clubBoard(String clubId, BoardMetric metric);
  Future<Result<Board>> worldBoard(BoardMetric metric, {String? country});

  Future<Result<void>> report({
    String? userId,
    String? clubId,
    required ReportReason reason,
    String? note,
  });
}

class DioCommunityApi implements CommunityApi {
  DioCommunityApi(this._dio);

  final Dio _dio;

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Ok(await call());
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }

  /// Wire encoders, public for the conformance test.
  static Map<String, dynamic> joinJson({
    required String handle,
    required String? country,
    required bool onWorld,
    required String policyVersion,
  }) =>
      {
        'handle': handle,
        'country': country,
        'onWorld': onWorld,
        'policyVersion': policyVersion,
      };

  static Map<String, dynamic> updateJson({
    String? handle,
    String? country,
    bool clearCountry = false,
    bool? onWorld,
  }) =>
      {
        if (handle != null) 'handle': handle,
        if (clearCountry)
          'country': null
        else if (country != null)
          'country': country,
        if (onWorld != null) 'onWorld': onWorld,
      };

  static Map<String, dynamic> reportJson({
    String? userId,
    String? clubId,
    required ReportReason reason,
    String? note,
  }) =>
      {
        if (userId != null) 'userId': userId,
        if (clubId != null) 'clubId': clubId,
        'reason': reason.wire,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      };

  @override
  Future<Result<CommunityMe>> me() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/v1/community/me');
        return CommunityMe.fromJson(r.data!);
      });

  @override
  Future<Result<CommunityMe>> join({
    required String handle,
    required String? country,
    required bool onWorld,
    required String policyVersion,
  }) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/v1/community/me',
          data: joinJson(
            handle: handle,
            country: country,
            onWorld: onWorld,
            policyVersion: policyVersion,
          ),
        );
        return CommunityMe.fromJson(r.data!);
      });

  @override
  Future<Result<CommunityMe>> update({
    String? handle,
    String? country,
    bool clearCountry = false,
    bool? onWorld,
  }) =>
      _guard(() async {
        final r = await _dio.patch<Map<String, dynamic>>(
          '/v1/community/me',
          data: updateJson(
            handle: handle,
            country: country,
            clearCountry: clearCountry,
            onWorld: onWorld,
          ),
        );
        return CommunityMe.fromJson(r.data!);
      });

  @override
  Future<Result<void>> leave() =>
      _guard(() => _dio.delete<void>('/v1/community/me'));

  List<CommunityPerson> _people(Map<String, dynamic>? data) => [
        for (final p in data!['items'] as List<dynamic>)
          CommunityPerson.fromJson(p as Map<String, dynamic>),
      ];

  @override
  Future<Result<List<CommunityPerson>>> search(String q) => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/v1/community/people',
          queryParameters: {'q': q},
        );
        return _people(r.data);
      });

  @override
  Future<Result<FriendLists>> friends() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/v1/community/friends');
        return FriendLists.fromJson(r.data!);
      });

  @override
  Future<Result<String>> addFriend(String handle) => _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/v1/community/friends',
          data: {'handle': handle},
        );
        return r.data!['status'] as String;
      });

  @override
  Future<Result<void>> accept(String userId) => _guard(
        () => _dio.post<void>('/v1/community/friends/$userId/accept'),
      );

  @override
  Future<Result<void>> unfriend(String userId) =>
      _guard(() => _dio.delete<void>('/v1/community/friends/$userId'));

  @override
  Future<Result<List<CommunityPerson>>> blocked() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/v1/community/blocks');
        return _people(r.data);
      });

  @override
  Future<Result<void>> block(String userId) => _guard(
        () => _dio.post<void>('/v1/community/blocks', data: {'userId': userId}),
      );

  @override
  Future<Result<void>> unblock(String userId) =>
      _guard(() => _dio.delete<void>('/v1/community/blocks/$userId'));

  @override
  Future<Result<List<Club>>> clubs() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/v1/community/clubs');
        return [
          for (final c in r.data!['items'] as List<dynamic>)
            Club.fromJson(c as Map<String, dynamic>),
        ];
      });

  @override
  Future<Result<Club>> createClub(String name) => _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/v1/community/clubs',
          data: {'name': name.trim()},
        );
        return Club.fromJson(r.data!);
      });

  @override
  Future<Result<Club>> joinClub(String code) => _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/v1/community/clubs/join',
          data: {'code': code.trim()},
        );
        return Club.fromJson(r.data!);
      });

  @override
  Future<Result<void>> leaveClub(String clubId) => _guard(
        () => _dio.delete<void>('/v1/community/clubs/$clubId/membership'),
      );

  @override
  Future<Result<PersonProfile>> personProfile(String userId) =>
      _guard(() async {
        final r = await _dio
            .get<Map<String, dynamic>>('/v1/community/people/$userId');
        return PersonProfile.fromJson(r.data!);
      });

  @override
  Future<Result<Club>> renameClub(String clubId, String name) =>
      _guard(() async {
        final r = await _dio.patch<Map<String, dynamic>>(
          '/v1/community/clubs/$clubId',
          data: {'name': name.trim()},
        );
        return Club.fromJson(r.data!);
      });

  @override
  Future<Result<Club>> newClubCode(String clubId) => _guard(() async {
        final r = await _dio
            .post<Map<String, dynamic>>('/v1/community/clubs/$clubId/code');
        return Club.fromJson(r.data!);
      });

  @override
  Future<Result<Club>> passClub(String clubId, String userId) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/v1/community/clubs/$clubId/owner',
          data: {'userId': userId},
        );
        return Club.fromJson(r.data!);
      });

  @override
  Future<Result<void>> removeMember(String clubId, String userId) => _guard(
        () => _dio.delete<void>('/v1/community/clubs/$clubId/members/$userId'),
      );

  @override
  Future<Result<List<CommunityPerson>>> removedFrom(String clubId) =>
      _guard(() async {
        final r = await _dio
            .get<Map<String, dynamic>>('/v1/community/clubs/$clubId/removed');
        return _people(r.data);
      });

  @override
  Future<Result<void>> letBack(String clubId, String userId) => _guard(
        () => _dio.delete<void>('/v1/community/clubs/$clubId/removed/$userId'),
      );

  Future<Board> _board(String path, Map<String, dynamic> query) async {
    final r =
        await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
    return Board.fromJson(r.data!);
  }

  @override
  Future<Result<Board>> friendsBoard(BoardMetric metric) => _guard(
        () => _board('/v1/community/boards/friends', {'metric': metric.wire}),
      );

  @override
  Future<Result<Board>> clubBoard(String clubId, BoardMetric metric) => _guard(
        () => _board(
          '/v1/community/boards/clubs/$clubId',
          {'metric': metric.wire},
        ),
      );

  @override
  Future<Result<Board>> worldBoard(BoardMetric metric, {String? country}) =>
      _guard(
        () => _board('/v1/community/boards/world', {
          'metric': metric.wire,
          if (country != null) 'country': country,
        }),
      );

  @override
  Future<Result<void>> report({
    String? userId,
    String? clubId,
    required ReportReason reason,
    String? note,
  }) =>
      _guard(
        () => _dio.post<void>(
          '/v1/community/reports',
          data: reportJson(
            userId: userId,
            clubId: clubId,
            reason: reason,
            note: note,
          ),
        ),
      );
}
