// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `device_calendar_retrieve_events_missing_end_date`.
library;

import 'package:device_calendar/device_calendar.dart';

void bad() {
  // expect_lint: device_calendar_retrieve_events_missing_end_date
  RetrieveEventsParams(startDate: DateTime.now());
}

void good() {
  RetrieveEventsParams(startDate: DateTime.now(), endDate: DateTime.now());
}
