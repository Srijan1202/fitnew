import 'package:fitos/core/errors/error_mapper.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorMapper.fromEnvelope — the §10 envelope', () {
    Map<String, dynamic> envelope(
      String code, {
      List<Map<String, String>>? details,
    }) =>
        {
          'error': {
            'code': code,
            'message': 'msg',
            if (details != null) 'details': details,
            'requestId': 'req-1',
          },
        };

    test('maps each code to its Failure', () {
      expect(
        ErrorMapper.fromEnvelope(401, envelope('UNAUTHENTICATED')),
        isA<Unauthenticated>(),
      );
      expect(
        ErrorMapper.fromEnvelope(429, envelope('RATE_LIMITED')),
        isA<RateLimited>(),
      );
      expect(
        ErrorMapper.fromEnvelope(500, envelope('INTERNAL')),
        isA<Unknown>(),
      );
    });

    test(
        'Phase 6.6 Gate 7: a 404 is NotFound and keeps the server message (the sync engine acts on it)',
        () {
      final f = ErrorMapper.fromEnvelope(404, {
        'error': {
          'code': 'NOT_FOUND',
          'message': 'That day is not in your active programme.',
          'requestId': 'r',
        },
      });
      expect(f, isA<NotFound>());
      expect(f.message, 'That day is not in your active programme.');
      expect(ErrorMapper.fromEnvelope(404, 'not json'), isA<NotFound>());
    });

    test('carries the failing field for validation errors', () {
      final f = ErrorMapper.fromEnvelope(
        422,
        envelope(
          'VALIDATION_FAILED',
          details: [
            {'path': 'timezone', 'issue': 'bad'},
          ],
        ),
      );
      expect(f, isA<Validation>());
      expect((f as Validation).field, 'timezone');
    });

    test('falls back to the status code when the body is not ours', () {
      expect(ErrorMapper.fromEnvelope(401, 'not json'), isA<Unauthenticated>());
      expect(ErrorMapper.fromEnvelope(422, null), isA<Validation>());
      expect(ErrorMapper.fromEnvelope(503, '<html>'), isA<Unknown>());
    });
  });

  group('deviceLocaleTag', () {
    test('turns platform locales into BCP 47 the server accepts', () {
      expect(deviceLocaleTag('en_IN'), 'en-IN');
      expect(deviceLocaleTag('hi_IN'), 'hi-IN');
      expect(deviceLocaleTag('en'), 'en');
    });

    test('drops the parts the server would reject rather than failing sign-in',
        () {
      expect(deviceLocaleTag('en_US_POSIX'), 'en-US');
      expect(deviceLocaleTag('zh_Hans_CN'), 'zh'); // script tag is not a region
      expect(deviceLocaleTag('C'), isNull);
      expect(deviceLocaleTag(''), isNull);
    });
  });
}
