// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `file_picker_path_on_web` (experimental).
/// BAD: force-unwrap .path. GOOD: guarded by !kIsWeb.
library;

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

void bad(PlatformFile file) {
  // expect_lint: file_picker_path_on_web
  final path = file.path!;
}

void good(PlatformFile file) {
  if (!kIsWeb) {
    final path = file.path!;
  }
}
