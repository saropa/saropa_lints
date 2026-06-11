// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `image_picker_camera_source_without_support_check` (WARNING).
library;

import 'package:image_picker/image_picker.dart';

final ImagePicker _picker = ImagePicker();

Future<void> bad() async {
  // expect_lint: image_picker_camera_source_without_support_check
  await _picker.pickImage(source: ImageSource.camera);
}

Future<void> good() async {
  if (_picker.supportsImageSource(ImageSource.camera)) {
    await _picker.pickImage(source: ImageSource.camera);
  }
}
