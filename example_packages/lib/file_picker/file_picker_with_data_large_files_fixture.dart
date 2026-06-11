// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `file_picker_with_data_large_files`.
library;

import 'package:file_picker/file_picker.dart';

Future<void> bad() async {
  // expect_lint: file_picker_with_data_large_files
  await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
}

Future<void> good() async {
  await FilePicker.platform.pickFiles(allowMultiple: true);
}
