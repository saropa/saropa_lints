// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `device_calendar_event_missing_calendar_id` (ERROR).
library;

import 'package:device_calendar/device_calendar.dart';

final plugin = DeviceCalendarPlugin();

Future<void> bad() async {
  await plugin.hasPermissions();
  // expect_lint: device_calendar_event_missing_calendar_id
  await plugin.createOrUpdateEvent(Event(title: 'x'));
}

Future<void> good() async {
  await plugin.hasPermissions();
  await plugin.createOrUpdateEvent(Event(calendarId: 'c', title: 'x'));
}
