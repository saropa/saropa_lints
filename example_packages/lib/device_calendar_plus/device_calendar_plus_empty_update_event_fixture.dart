// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `device_calendar_plus_empty_update_event`.
library;

import 'package:device_calendar_plus/device_calendar_plus.dart';

Future<void> bad(String eventId) async {
  // expect_lint: device_calendar_plus_empty_update_event
  await DeviceCalendar.instance.updateEvent(eventId: eventId);
}

Future<void> good(String eventId) async {
  // Also keeps device_calendar_plus_missing_permission_check quiet for this
  // fixture file, so only the empty-update rule under test fires above.
  await DeviceCalendar.instance.requestPermissions();
  await DeviceCalendar.instance.updateEvent(
    eventId: eventId,
    title: 'New title',
  );
}
