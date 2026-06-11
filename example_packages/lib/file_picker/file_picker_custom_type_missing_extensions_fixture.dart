// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `file_picker_custom_type_missing_extensions` (ERROR).
library;

import 'package:file_picker/file_picker.dart';

Future<void> bad() async {
  // expect_lint: file_picker_custom_type_missing_extensions
  await FilePicker.platform.pickFiles(type: FileType.custom);
}

Future<void> good() async {
  await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
}
