// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `permission_handler_status_without_request` (INFO).
///
/// The bad case checks a status getter but never calls request() anywhere in
/// the file; the good case is in a separate fixture file (a request present in
/// the same file clears the whole unit), so here good() shows the request form.
library;

import 'package:permission_handler/permission_handler.dart';

Future<void> bad() async {
  // expect_lint: permission_handler_status_without_request
  if (await Permission.camera.isGranted) {
    return;
  }
}
