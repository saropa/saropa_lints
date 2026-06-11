// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `device_calendar_result_data_before_success_check`.
library;

import 'package:device_calendar/device_calendar.dart';

final plugin = DeviceCalendarPlugin();

Future<void> bad() async {
  await plugin.hasPermissions();
  final r = await plugin.retrieveCalendars();
  // expect_lint: device_calendar_result_data_before_success_check
  final list = r.data;
}

Future<void> good() async {
  await plugin.hasPermissions();
  final r = await plugin.retrieveCalendars();
  if (r.isSuccess) {
    final list = r.data;
  }
}
