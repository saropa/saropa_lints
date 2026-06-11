// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `permission_handler_batched_request_preferred` (INFO).
library;

import 'package:permission_handler/permission_handler.dart';

Future<void> bad() async {
  await Permission.camera.request();
  // expect_lint: permission_handler_batched_request_preferred
  await Permission.microphone.request();
}

Future<void> good() async {
  await [Permission.camera, Permission.microphone].request();
}

Future<void> goodSequentialGated() async {
  // Second request gated on the first result — intentional sequential flow.
  final whenInUse = await Permission.locationWhenInUse.request();
  if (whenInUse.isGranted) {
    await Permission.locationAlways.request();
  }
}
