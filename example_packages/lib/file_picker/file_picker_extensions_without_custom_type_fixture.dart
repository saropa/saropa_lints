// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `file_picker_extensions_without_custom_type`.
library;

import 'package:file_picker/file_picker.dart';

Future<void> bad() async {
  // expect_lint: file_picker_extensions_without_custom_type
  await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowedExtensions: ['png'],
  );
}

Future<void> good() async {
  await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png'],
  );
}
