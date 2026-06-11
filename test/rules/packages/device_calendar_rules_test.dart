import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/device_calendar_rules.dart';

/// Tests for 7 device_calendar lint rules.
///
/// Test fixtures: example_packages/lib/device_calendar/*
void main() {
  group('DeviceCalendar Rules - Rule Instantiation', () {
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
      'DeviceCalendarMissingPermissionCheckRule',
      'device_calendar_missing_permission_check',
      () => DeviceCalendarMissingPermissionCheckRule(),
    );
    testRule(
      'DeviceCalendarUncheckedResultRule',
      'device_calendar_unchecked_result',
      () => DeviceCalendarUncheckedResultRule(),
    );
    testRule(
      'DeviceCalendarRetrieveEventsEmptyParamsRule',
      'device_calendar_retrieve_events_empty_params',
      () => DeviceCalendarRetrieveEventsEmptyParamsRule(),
    );
    testRule(
      'DeviceCalendarRetrieveEventsMissingEndDateRule',
      'device_calendar_retrieve_events_missing_end_date',
      () => DeviceCalendarRetrieveEventsMissingEndDateRule(),
    );
    testRule(
      'DeviceCalendarEventMissingCalendarIdRule',
      'device_calendar_event_missing_calendar_id',
      () => DeviceCalendarEventMissingCalendarIdRule(),
    );
    testRule(
      'DeviceCalendarEventUtcTimezoneRule',
      'device_calendar_event_utc_timezone',
      () => DeviceCalendarEventUtcTimezoneRule(),
    );
    testRule(
      'DeviceCalendarResultDataBeforeSuccessCheckRule',
      'device_calendar_result_data_before_success_check',
      () => DeviceCalendarResultDataBeforeSuccessCheckRule(),
    );
  });

  group('DeviceCalendar Rules - Fixture Verification', () {
    final fixtures = [
      'device_calendar_missing_permission_check',
      'device_calendar_unchecked_result',
      'device_calendar_retrieve_events_empty_params',
      'device_calendar_retrieve_events_missing_end_date',
      'device_calendar_event_missing_calendar_id',
      'device_calendar_event_utc_timezone',
      'device_calendar_result_data_before_success_check',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/device_calendar/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
