// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `device_calendar_missing_permission_check` (INFO).
/// BAD: data ops with no hasPermissions/requestPermissions in the file.
library;

import 'package:device_calendar/device_calendar.dart';

final plugin = DeviceCalendarPlugin();

Future<void> bad() async {
  // expect_lint: device_calendar_missing_permission_check
  final r = await plugin.retrieveCalendars();
}
