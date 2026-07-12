// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `device_calendar_plus_all_day_event_utc_conversion`.
library;

import 'package:device_calendar_plus/device_calendar_plus.dart';

Future<void> bad() async {
  await DeviceCalendar.instance.createEvent(
    title: 'Birthday',
    isAllDay: true,
    // expect_lint: device_calendar_plus_all_day_event_utc_conversion
    startDate: DateTime.now().toUtc(),
    endDate: DateTime.now(),
  );
}

// Covers the two UTC shapes added alongside .toUtc()/DateTime.utc(...):
// fromMillisecondsSinceEpoch(isUtc: true) and a Z-suffixed parsed string.
Future<void> badOtherUtcShapes() async {
  await DeviceCalendar.instance.createEvent(
    title: 'Birthday',
    isAllDay: true,
    // expect_lint: device_calendar_plus_all_day_event_utc_conversion
    startDate: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    // expect_lint: device_calendar_plus_all_day_event_utc_conversion
    endDate: DateTime.parse('2026-01-16T00:00:00Z'),
  );
}

Future<void> good() async {
  // Also keeps device_calendar_plus_missing_permission_check quiet for this
  // fixture file, so only the UTC-conversion rule under test fires above.
  await DeviceCalendar.instance.requestPermissions();
  await DeviceCalendar.instance.createEvent(
    title: 'Birthday',
    isAllDay: true,
    startDate: DateTime.now(),
    endDate: DateTime.now(),
  );
  // OK: DateTime.parse of a non-Z (local/offset) string is not UTC-tainted.
  await DeviceCalendar.instance.createEvent(
    title: 'Birthday',
    isAllDay: true,
    startDate: DateTime.parse('2026-01-15'),
    endDate: DateTime.parse('2026-01-16'),
  );
}

// OK: an unrelated class's same-named method, called with the exact
// isAllDay + UTC-tainted-startDate shape the rule looks for, is not a
// DeviceCalendar call — the rule requires the resolved receiver type to be
// DeviceCalendar, so this must not trigger even though the shape matches.
class EventFactory {
  Future<void> createEvent({
    required bool isAllDay,
    required DateTime startDate,
  }) async {}
}

Future<void> unrelatedSameNamedMethod() async {
  final factory = EventFactory();
  await factory.createEvent(isAllDay: true, startDate: DateTime.now().toUtc());
}
