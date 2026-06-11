// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `permission_handler_location_always_before_when_in_use`.
library;

import 'package:permission_handler/permission_handler.dart';

Future<void> bad() async {
  // expect_lint: permission_handler_location_always_before_when_in_use
  await Permission.locationAlways.request();
}

Future<void> good() async {
  await Permission.locationWhenInUse.request();
  await Permission.locationAlways.request();
}
