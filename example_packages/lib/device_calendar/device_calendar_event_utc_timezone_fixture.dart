// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `device_calendar_event_utc_timezone`.
library;

import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart';

void bad() {
  // expect_lint: device_calendar_event_utc_timezone
  Event(calendarId: 'c', start: TZDateTime.utc(2026, 1, 1));
}

void good(Location loc) {
  Event(calendarId: 'c', start: TZDateTime.from(DateTime.now(), loc));
}
