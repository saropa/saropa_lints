// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `file_picker_extension_with_dot`. Quick fix strips the dot.
library;

import 'package:file_picker/file_picker.dart';

Future<void> bad() async {
  await FilePicker.platform.pickFiles(
    type: FileType.custom,
    // expect_lint: file_picker_extension_with_dot
    allowedExtensions: ['.pdf'],
  );
}

Future<void> good() async {
  await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
}
