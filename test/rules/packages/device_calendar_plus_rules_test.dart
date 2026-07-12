import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/device_calendar_plus_rules.dart';

/// Tests for 3 device_calendar_plus lint rules.
///
/// Test fixtures: example_packages/lib/device_calendar_plus/*
void main() {
  group('DeviceCalendarPlus Rules - Rule Instantiation', () {
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
      'DeviceCalendarPlusMissingPermissionCheckRule',
      'device_calendar_plus_missing_permission_check',
      () => DeviceCalendarPlusMissingPermissionCheckRule(),
    );
    testRule(
      'DeviceCalendarPlusAllDayEventUtcConversionRule',
      'device_calendar_plus_all_day_event_utc_conversion',
      () => DeviceCalendarPlusAllDayEventUtcConversionRule(),
    );
    testRule(
      'DeviceCalendarPlusEmptyUpdateEventRule',
      'device_calendar_plus_empty_update_event',
      () => DeviceCalendarPlusEmptyUpdateEventRule(),
    );
  });

  group('DeviceCalendarPlus Rules - Fixture Verification', () {
    final fixtures = [
      'device_calendar_plus_missing_permission_check',
      'device_calendar_plus_all_day_event_utc_conversion',
      'device_calendar_plus_empty_update_event',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/device_calendar_plus/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
