// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `image_picker_missing_retrieve_lost_data` (WARNING).
library;

import 'package:image_picker/image_picker.dart';

final ImagePicker _picker = ImagePicker();

Future<void> bad() async {
  // expect_lint: image_picker_missing_retrieve_lost_data
  await _picker.pickImage(source: ImageSource.gallery);
}

Future<void> good() async {
  final lost = await _picker.retrieveLostData();
  await _picker.pickImage(source: ImageSource.gallery);
}
