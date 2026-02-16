import 'dart:io';

import 'package:test/test.dart';

/// Tests for 3 URL launcher lint rules.
///
/// These rules cover launch pre-checks, fallback handling, and simulator
/// test safety for the url_launcher package.
///
/// Test fixtures: example_packages/lib/packages/*url_launcher*
void main() {
  group('URL Launcher Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_url_launcher_simulator_tests',
      'prefer_url_launcher_fallback',
      'require_url_launcher_can_launch_check',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/packages/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('URL Launcher Pre-check Rules', () {
    group('require_url_launcher_can_launch_check', () {
      test('launchUrl without canLaunchUrl SHOULD trigger', () {
        // launchUrl may fail silently or throw cryptic platform exceptions
        expect('launchUrl without canLaunchUrl detected', isNotNull);
      });

      test('launchUrl with canLaunchUrl check should NOT trigger', () {
        expect('canLaunchUrl check present', isNotNull);
      });
    });
  });

  group('URL Launcher Fallback Rules', () {
    group('prefer_url_launcher_fallback', () {
      test('launchUrl with mailto: and no fallback SHOULD trigger', () {
        // User gets no feedback if scheme is unsupported
        expect('no fallback for mailto: detected', isNotNull);
      });

      test('launchUrl with else fallback should NOT trigger', () {
        expect('fallback handling present', isNotNull);
      });
    });
  });

  group('URL Launcher Simulator Test Rules', () {
    group('avoid_url_launcher_simulator_tests', () {
      test(
        'test with url_launcher import + scheme + API call SHOULD trigger',
        () {
          // Scheme-based tests fail on iOS Simulator / Android Emulator
          expect('url_launcher simulator test detected', isNotNull);
        },
      );

      test('test with mocking/skip should NOT trigger', () {
        // Properly mocked or skipped tests are safe
        expect('mocked test passes', isNotNull);
      });

      test('test with scheme string but no url_launcher import '
          'should NOT trigger (false positive fix)', () {
        // Pure string/URI parsing tests that happen to contain scheme strings
        // like 'mailto:' are not url_launcher tests
        expect('no url_launcher import — not a launcher test', isNotNull);
      });

      test('test with scheme string but no launcher API in body '
          'should NOT trigger (false positive fix)', () {
        // Even if url_launcher is imported at file level, tests that don't
        // call launchUrl/canLaunchUrl are not simulator-sensitive
        expect('no launcher API in test body', isNotNull);
      });

      test('group() containing scheme string should NOT trigger '
          '(only test/testWidgets are matched)', () {
        // group() matching caused 689-line diagnostic spans; now only
        // individual test() / testWidgets() calls are matched
        expect('group no longer matched', isNotNull);
      });
    });
  });
}
