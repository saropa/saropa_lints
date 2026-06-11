import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/connectivity_plus_rules.dart';

/// Instantiation-pin tests for connectivity_plus lint rules.
///
/// Verifies code names, problem-message contract (prefixed, >200 chars),
/// and fixture file presence.
///
/// Fixture: example_packages/lib/connectivity_plus/connectivity_plus_fixture.dart
void main() {
  group('ConnectivityPlus Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(
          rule.code.problemMessage,
          contains('[$codeName]'),
          reason: 'problem message must start with [$codeName] prefix',
        );
        expect(
          rule.code.problemMessage.length,
          greaterThan(200),
          reason: 'problem message must be >200 chars',
        );
        expect(
          rule.code.correctionMessage,
          isNotNull,
          reason: 'correctionMessage must be provided',
        );
      });
    }

    testRule(
      'AvoidPreV6SingleConnectivityResultRule',
      'avoid_pre_v6_single_connectivity_result',
      () => AvoidPreV6SingleConnectivityResultRule(),
    );

    testRule(
      'ConnectivitySatelliteMissingRule',
      'connectivity_satellite_missing',
      () => ConnectivitySatelliteMissingRule(),
    );
  });

  group('ConnectivityPlus Rules - Fix Presence', () {
    test('AvoidPreV6SingleConnectivityResultRule has fixGenerators', () {
      final rule = AvoidPreV6SingleConnectivityResultRule();
      expect(
        rule.fixGenerators,
        isNotEmpty,
        reason: 'avoid_pre_v6_single_connectivity_result must provide a fix',
      );
    });

    test('ConnectivitySatelliteMissingRule has no fixGenerators', () {
      final rule = ConnectivitySatelliteMissingRule();
      // No quick fix: the satellite branch behavior is caller-defined.
      // A TODO-only branch insert is banned by project quick-fix rules.
      expect(
        rule.fixGenerators,
        isEmpty,
        reason: 'connectivity_satellite_missing must NOT provide a quick fix',
      );
    });
  });

  group('ConnectivityPlus Rules - Fixture Verification', () {
    test('connectivity_plus fixture exists', () {
      final file = File(
        'example_packages/lib/connectivity_plus/connectivity_plus_fixture.dart',
      );
      expect(
        file.existsSync(),
        isTrue,
        reason: 'fixture file must exist at expected path',
      );
    });
  });
}
