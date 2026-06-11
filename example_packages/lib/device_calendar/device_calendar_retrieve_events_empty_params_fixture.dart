// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `device_calendar_retrieve_events_empty_params`.
library;

import 'package:device_calendar/device_calendar.dart';

final plugin = DeviceCalendarPlugin();

Future<void> bad() async {
  await plugin.hasPermissions();
  // expect_lint: device_calendar_retrieve_events_empty_params
  await plugin.retrieveEvents('c', RetrieveEventsParams());
}

Future<void> good() async {
  await plugin.hasPermissions();
  await plugin.retrieveEvents(
    'c',
    RetrieveEventsParams(startDate: DateTime.now(), endDate: DateTime.now()),
  );
}
