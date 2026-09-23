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
      expect(ErrorMapper.fromEnvelope(500, '<html>'), isA<Unknown>());
    });
  });

  group('Phase 6.7 — a hosted API that is reached but not answering', () {
    Map<String, dynamic> envelope(String code, String message) => {
          'error': {'code': code, 'message': message, 'requestId': 'r'},
        };
    const host = 'fitos-api-alpha-1.asia-south1.run.app';

    for (final status in <int>[502, 503, 504]) {
      test(
          '$status from the front end (no envelope) → ServiceUnavailable, an Offline, naming the host',
          () {
        final f = ErrorMapper.fromEnvelope(
          status,
          '<html><body>Service Unavailable</body></html>',
          authority: host,
        );
        expect(f, isA<ServiceUnavailable>());
        expect(f, isA<Offline>(), reason: 'waits like no network');
        expect(f.message, contains(host));
      });
    }

    test(
        '429 from Cloud Run (no envelope) → ServiceUnavailable, not RateLimited',
        () {
      final f =
          ErrorMapper.fromEnvelope(429, 'Rate exceeded.', authority: host);
      expect(f, isA<ServiceUnavailable>());
      expect(f, isNot(isA<RateLimited>()));
    });

    test(
        "429 from FITOS itself (RATE_LIMITED envelope) keeps the API's rate-limit meaning",
        () {
      final f = ErrorMapper.fromEnvelope(
        429,
        envelope('RATE_LIMITED', 'Too many requests. Slow down and retry.'),
        authority: host,
      );
      expect(f, isA<RateLimited>());
      expect(f.message, 'Too many requests. Slow down and retry.');
    });

    test(
        "FITOS's own 503 (UPSTREAM_UNAVAILABLE) → ServiceUnavailable with the server's words",
        () {
      for (final message in <String>[
        'FITOS is temporarily unavailable. Try again shortly.',
        'AI is not set up on this server.',
        'FITOS AI took too long to answer. Try again.',
      ]) {
        final f = ErrorMapper.fromEnvelope(
          503,
          envelope('UPSTREAM_UNAVAILABLE', message),
          authority: host,
        );
        expect(f, isA<ServiceUnavailable>());
        expect(f.message, message);
      }
    });

    test(
        'a 500 (a real server bug) is still Unknown — counted and parked as before',
        () {
      expect(ErrorMapper.fromEnvelope(500, 'oops'), isA<Unknown>());
      expect(
        ErrorMapper.fromEnvelope(500, envelope('INTERNAL', 'x')),
        isA<Unknown>(),
      );
      expect(ErrorMapper.fromEnvelope(500, 'oops'), isNot(isA<Offline>()));
    });

    test('without a host the message still reads well', () {
      expect(
        ErrorMapper.fromEnvelope(502, null).message,
        'FITOS is not answering right now. Try again in a moment.',
      );
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
