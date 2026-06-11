// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `image_picker_multi_result_unchecked_empty` (ERROR).
library;

import 'package:image_picker/image_picker.dart';

final ImagePicker _picker = ImagePicker();

Future<void> bad() async {
  final files = await _picker.pickMultiImage();
  // expect_lint: image_picker_multi_result_unchecked_empty
  final first = files[0];
}

Future<void> good() async {
  final files = await _picker.pickMultiImage();
  if (files.isNotEmpty) {
    final first = files[0];
  }
}
