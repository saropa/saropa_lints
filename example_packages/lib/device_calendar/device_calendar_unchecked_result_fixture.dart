// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `device_calendar_unchecked_result`.
/// BAD: discarded await. GOOD: assigned + isSuccess checked.
library;

import 'package:device_calendar/device_calendar.dart';

final plugin = DeviceCalendarPlugin();

Future<void> bad() async {
  await plugin.hasPermissions();
  // expect_lint: device_calendar_unchecked_result
  await plugin.deleteEvent('c', 'e');
}

Future<void> good() async {
  await plugin.hasPermissions();
  final r = await plugin.deleteEvent('c', 'e');
  if (!r.isSuccess) return;
}
