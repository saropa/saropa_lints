// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `device_calendar_plus_missing_permission_check` (INFO).
/// BAD: data ops with no hasPermissions/requestPermissions/autoPermissions
/// anywhere in the file.
library;

import 'package:device_calendar_plus/device_calendar_plus.dart';

// No `good()` counterpart here: this rule scans the whole file for a
// permission call, so a compliant call anywhere in the file would suppress
// the diagnostic above and defeat the fixture.
Future<void> bad() async {
  // expect_lint: device_calendar_plus_missing_permission_check
  final calendars = await DeviceCalendar.instance.listCalendars();
}
