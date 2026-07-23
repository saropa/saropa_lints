import 'dart:io';

import 'package:saropa_lints/src/rules/network/connectivity_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 3 Connectivity lint rules.
///
/// Test fixtures: example/lib/connectivity/*
void main() {
  group('Connectivity Rules - Rule Instantiation', () {
    test('RequireConnectivityErrorHandlingRule', () {
      final rule = RequireConnectivityErrorHandlingRule();
      expect(rule.code.lowerCaseName, 'require_connectivity_error_handling');
      expect(
        rule.code.problemMessage,
        contains('[require_connectivity_error_handling]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidConnectivityEqualsInternetRule', () {
      final rule = AvoidConnectivityEqualsInternetRule();
      expect(rule.code.lowerCaseName, 'avoid_connectivity_equals_internet');
      expect(
        rule.code.problemMessage,
        contains('[avoid_connectivity_equals_internet]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireConnectivityTimeoutRule', () {
      final rule = RequireConnectivityTimeoutRule();
      expect(rule.code.lowerCaseName, 'require_connectivity_timeout');
      expect(
        rule.code.problemMessage,
        contains('[require_connectivity_timeout]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Connectivity Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/connectivity');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/connectivity/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
