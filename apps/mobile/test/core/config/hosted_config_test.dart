import 'package:fitos/core/config/env.dart';
import 'package:fitos/core/config/hosted_api_url.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 6.7 Gate 6.7-2 — the hosted build profile's address rules, and that
/// the LAN alpha / local profiles are NOT subject to them.
void main() {
  group('hostedApiUrlProblem — accepted', () {
    for (final url in <String>[
      // Cloud Run's deterministic URL for fitos-api-alpha in asia-south1.
      'https://fitos-api-alpha-123456789012.asia-south1.run.app',
      // Cloud Run's older hashed form.
      'https://fitos-api-alpha-abcd1234ef-el.a.run.app',
      // Later, once the domain is set up (not configured in 6.7-2).
      'https://api.tryfitos.me',
      'https://api.tryfitos.me/',
      '  https://api.tryfitos.me  ',
    ]) {
      test(url.trim(), () => expect(hostedApiUrlProblem(url), isNull));
    }
  });

  group('hostedApiUrlProblem — rejected', () {
    for (final (url, reason) in <(String, String)>[
      ('http://fitos-api-alpha-1.asia-south1.run.app', 'https'),
      ('http://10.160.235.11:8080', 'https'),
      ('https://localhost', 'localhost'),
      ('https://api.localhost', 'localhost'),
      ('https://127.0.0.1', 'IP address'),
      ('https://10.0.2.2', 'IP address'),
      ('https://192.168.1.20', 'IP address'),
      ('https://10.160.235.11', 'IP address'),
      ('https://[::1]', 'IP address'),
      ('https://[2001:db8::1]', 'IP address'),
      ('https://0x7f.0.0.1', 'IP address'),
      ('https://api.tryfitos.me:443', 'port'),
      ('https://api.tryfitos.me:8080', 'port'),
      ('https://fitos-api-alpha-1.asia-south1.run.app:8443', 'port'),
      ('https://fitos-api', 'DNS name'),
      ('https://api.tryfitos.me/v1', 'path'),
      ('https://api.tryfitos.me/?x=1', 'query'),
      ('https://user:pw@api.tryfitos.me', 'credentials'),
      ('api.tryfitos.me', 'https'),
      ('', 'empty'),
    ]) {
      test('$url → $reason', () {
        final problem = hostedApiUrlProblem(url);
        expect(problem, isNotNull, reason: url);
        expect(problem, contains(reason));
      });
    }
  });

  group('Env — the hosted profile beside the LAN profile', () {
    test('a hosted build with an http / IP / port address cannot start', () {
      for (final url in <String>[
        'http://10.160.235.11:8080',
        'https://10.0.2.2',
        'https://api.tryfitos.me:443',
      ]) {
        expect(
          Env.configurationProblemFor(flavor: 'hosted', apiBaseUrl: url),
          startsWith('API_BASE_URL '),
          reason: url,
        );
      }
      expect(
        Env.configurationProblemFor(
          flavor: 'hosted',
          apiBaseUrl:
              'https://fitos-api-alpha-123456789012.asia-south1.run.app',
        ),
        isNull,
      );
    });

    test(
        'LAN alpha and local builds keep their http://<IP>:8080 addresses (Phase 6.6 unchanged)',
        () {
      for (final (flavor, url) in <(String, String)>[
        ('alpha', 'http://10.160.235.11:8080'),
        ('alpha', 'http://192.168.1.20:8080'),
        ('local', 'http://10.0.2.2:8080'),
      ]) {
        expect(
          Env.configurationProblemFor(flavor: flavor, apiBaseUrl: url),
          isNull,
          reason: '$flavor $url',
        );
      }
    });

    test('the sign-in screen names the backend for alpha and hosted, not local',
        () {
      expect(Env.showsBackendFor('alpha'), isTrue);
      expect(Env.showsBackendFor('hosted'), isTrue);
      expect(Env.showsBackendFor('local'), isFalse);
    });

    test(
        'this test run (no FLAVOR define) is the local profile and ready to use',
        () {
      expect(Env.flavor, 'local');
      expect(Env.isHosted, isFalse);
      expect(Env.configurationProblem, isNull);
    });
  });
}
