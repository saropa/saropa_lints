// Integration tests for the LINT_MESSAGE and LINT_NOT fixture marker
// infrastructure.
//
// Validates that `assertFixtureMarkers` correctly:
// - matches diagnostics to `// LINT:` markers by rule name and line
// - asserts message substrings from `// LINT_MESSAGE:` markers
// - rejects diagnostics on `// LINT_NOT:` lines (false-positive guards)
// - fails when expectations are violated
//
// Uses `require_ignore_comment_plugin_prefix` because it emits two distinct
// message variants depending on the condition: "without the required" for bare
// saropa rule names, and "not a registered" for prefixed-but-unknown rules.
library;

import 'package:saropa_lints/src/rules/stylistic/formatting_rules.dart';
import 'package:test/test.dart';

import 'fixture_message_harness.dart';

void main() {
  group('assertFixtureMarkers', () {
    final rule = RequireIgnoreCommentPluginPrefixRule();

    test('validates bare-name message via LINT_MESSAGE marker', () async {
      // Bare saropa rule name should emit the "without the required" message.
      await assertFixtureMarkers(rule, '''
// LINT: require_ignore_comment_plugin_prefix
// LINT_MESSAGE: without the required
// ignore: avoid_null_assertion
final x = 1;
''');
    });

    test('validates prefixed-unknown message via LINT_MESSAGE marker', () async {
      // Prefixed but unregistered rule name should emit "not a registered".
      await assertFixtureMarkers(rule, '''
// LINT: require_ignore_comment_plugin_prefix
// LINT_MESSAGE: not a registered
// ignore: saropa_lints/totally_fake_rule
final x = 1;
''');
    });

    test('validates LINT marker without LINT_MESSAGE (line-only)', () async {
      // Without LINT_MESSAGE, only checks that the rule fires on the right line.
      await assertFixtureMarkers(rule, '''
// LINT: require_ignore_comment_plugin_prefix
// ignore: avoid_null_assertion
final x = 1;
''');
    });

    test('validates multiple markers in one source', () async {
      // Mix of bare-name and prefixed-unknown in the same fixture.
      await assertFixtureMarkers(rule, '''
// LINT: require_ignore_comment_plugin_prefix
// LINT_MESSAGE: without the required
// ignore: avoid_null_assertion
final x1 = 1;
// LINT: require_ignore_comment_plugin_prefix
// LINT_MESSAGE: not a registered
// ignore: saropa_lints/totally_fake_rule
final x2 = 2;
''');
    });

    test('fails when LINT_MESSAGE substring does not match', () async {
      // Deliberately wrong message substring to verify the assertion fails.
      expect(
        () => assertFixtureMarkers(rule, '''
// LINT: require_ignore_comment_plugin_prefix
// LINT_MESSAGE: this text will not match anything
// ignore: avoid_null_assertion
final x = 1;
'''),
        throwsA(isA<TestFailure>()),
      );
    });

    test('fails when no LINT markers are present', () async {
      // Source with no markers should fail the guard assertion.
      expect(
        () => assertFixtureMarkers(rule, '''
// ignore: avoid_null_assertion
final x = 1;
'''),
        throwsA(isA<TestFailure>()),
      );
    });

    test('validates LINT_NOT marker (false-positive guard)', () async {
      // Prefixed registered rule — no diagnostic expected.
      await assertFixtureMarkers(rule, '''
// LINT_NOT: require_ignore_comment_plugin_prefix
// ignore: saropa_lints/avoid_null_assertion
final x = 1;
''');
    });

    test('validates LINT_NOT with non-saropa rule (no diagnostic)', () async {
      // Core Dart lint — rule should not fire.
      await assertFixtureMarkers(rule, '''
// LINT_NOT: require_ignore_comment_plugin_prefix
// ignore: unused_import
final x = 1;
''');
    });

    test('validates mixed LINT and LINT_NOT in same source', () async {
      // Positive and negative markers in one fixture.
      await assertFixtureMarkers(rule, '''
// LINT: require_ignore_comment_plugin_prefix
// LINT_MESSAGE: without the required
// ignore: avoid_null_assertion
final x1 = 1;
// LINT_NOT: require_ignore_comment_plugin_prefix
// ignore: saropa_lints/avoid_null_assertion
final x2 = 2;
''');
    });

    test('fails when LINT_NOT line has a diagnostic', () async {
      // LINT_NOT on a bare saropa rule name — the rule WILL fire, so the
      // negative assertion should fail.
      expect(
        () => assertFixtureMarkers(rule, '''
// LINT_NOT: require_ignore_comment_plugin_prefix
// ignore: avoid_null_assertion
final x = 1;
'''),
        throwsA(isA<TestFailure>()),
      );
    });

    test('LINT_NOT-only source is valid (no LINT markers needed)', () async {
      // Source with only negative markers — no positive markers required.
      await assertFixtureMarkers(rule, '''
// LINT_NOT: require_ignore_comment_plugin_prefix
// ignore: unused_import
final x = 1;
''');
    });

    test('validates LINT_COUNT with correct count', () async {
      // Two bare saropa rule names → exactly 2 diagnostics expected.
      await assertFixtureMarkers(rule, '''
// LINT_COUNT: require_ignore_comment_plugin_prefix 2
// ignore: avoid_null_assertion
final x1 = 1;
// ignore: avoid_null_assertion
final x2 = 2;
''');
    });

    test('validates LINT_COUNT zero (no diagnostics)', () async {
      // Only compliant code — zero diagnostics expected.
      await assertFixtureMarkers(rule, '''
// LINT_COUNT: require_ignore_comment_plugin_prefix 0
// ignore: saropa_lints/avoid_null_assertion
final x = 1;
''');
    });

    test('fails when LINT_COUNT does not match actual count', () async {
      // Claims 5 but only 1 diagnostic will fire.
      expect(
        () => assertFixtureMarkers(rule, '''
// LINT_COUNT: require_ignore_comment_plugin_prefix 5
// ignore: avoid_null_assertion
final x = 1;
'''),
        throwsA(isA<TestFailure>()),
      );
    });

    test('LINT_COUNT-only source is valid', () async {
      // Source with only a count marker — no LINT/LINT_NOT required.
      await assertFixtureMarkers(rule, '''
// LINT_COUNT: require_ignore_comment_plugin_prefix 1
// ignore: avoid_null_assertion
final x = 1;
''');
    });

    test('validates mixed LINT, LINT_NOT, and LINT_COUNT', () async {
      // All three marker types in one fixture.
      await assertFixtureMarkers(rule, '''
// LINT_COUNT: require_ignore_comment_plugin_prefix 1
// LINT: require_ignore_comment_plugin_prefix
// LINT_MESSAGE: without the required
// ignore: avoid_null_assertion
final x1 = 1;
// LINT_NOT: require_ignore_comment_plugin_prefix
// ignore: saropa_lints/avoid_null_assertion
final x2 = 2;
''');
    });
  });
}
