import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/sensors_plus_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Instantiation-pin tests for 4 sensors_plus lint rules.
///
/// Test fixtures: example_packages/lib/sensors_plus/*
void main() {
  group('SensorsPlus Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'PreferSensorsEventStreamRule',
      'prefer_sensors_event_stream',
      () => PreferSensorsEventStreamRule(),
    );

    testRule(
      'SensorsPlusNoSamplingPeriodRule',
      'sensors_plus_no_sampling_period',
      () => SensorsPlusNoSamplingPeriodRule(),
    );

    testRule(
      'SensorsPlusFastestIntervalRule',
      'sensors_plus_fastest_interval',
      () => SensorsPlusFastestIntervalRule(),
    );

    testRule(
      'SensorsPlusMissingOnErrorRule',
      'sensors_plus_missing_on_error',
      () => SensorsPlusMissingOnErrorRule(),
    );
  });

  group('SensorsPlus Rules - Fix Presence', () {
    test('prefer_sensors_event_stream has a quick fix', () {
      final rule = PreferSensorsEventStreamRule();
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('sensors_plus_no_sampling_period has a quick fix', () {
      final rule = SensorsPlusNoSamplingPeriodRule();
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('sensors_plus_fastest_interval has a quick fix', () {
      final rule = SensorsPlusFastestIntervalRule();
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('sensors_plus_missing_on_error has NO quick fix (report-only)', () {
      final rule = SensorsPlusMissingOnErrorRule();
      expect(rule.fixGenerators, isEmpty);
    });
  });

  group('SensorsPlus Rules - Severity', () {
    test('prefer_sensors_event_stream is WARNING', () {
      final rule = PreferSensorsEventStreamRule();
      expect(rule.code.severity.displayName.toLowerCase(), 'warning');
    });

    test('sensors_plus_no_sampling_period is INFO', () {
      final rule = SensorsPlusNoSamplingPeriodRule();
      expect(rule.code.severity.displayName.toLowerCase(), 'info');
    });

    test('sensors_plus_fastest_interval is INFO', () {
      final rule = SensorsPlusFastestIntervalRule();
      expect(rule.code.severity.displayName.toLowerCase(), 'info');
    });

    test('sensors_plus_missing_on_error is INFO', () {
      final rule = SensorsPlusMissingOnErrorRule();
      expect(rule.code.severity.displayName.toLowerCase(), 'info');
    });
  });

  group('SensorsPlus Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/sensors_plus');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/sensors_plus/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
