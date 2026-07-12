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
}
