// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `permission_handler_deprecated_calendar`.
library;

import 'package:permission_handler/permission_handler.dart';

Future<void> bad() async {
  // expect_lint: permission_handler_deprecated_calendar
  await Permission.calendar.request();
}

Future<void> good() async {
  await Permission.calendarFullAccess.request();
}
