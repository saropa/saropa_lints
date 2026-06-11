// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `image_picker_invalid_image_quality` (ERROR).
library;

import 'package:image_picker/image_picker.dart';

final ImagePicker _picker = ImagePicker();

Future<void> bad() async {
  // expect_lint: image_picker_invalid_image_quality
  await _picker.pickImage(source: ImageSource.gallery, imageQuality: 150);
}

Future<void> good() async {
  await _picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
}
