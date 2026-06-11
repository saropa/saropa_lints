// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `file_picker_unchecked_null_result`.
/// BAD: use .files on a nullable result. GOOD: null-check first.
library;

import 'package:file_picker/file_picker.dart';

Future<void> bad() async {
  final r = await FilePicker.platform.pickFiles();
  // expect_lint: file_picker_unchecked_null_result
  final files = r.files;
}

Future<void> good() async {
  final r = await FilePicker.platform.pickFiles();
  if (r == null) return;
  final files = r.files;
}
