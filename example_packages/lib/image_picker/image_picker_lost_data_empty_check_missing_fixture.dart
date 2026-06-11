// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `image_picker_lost_data_empty_check_missing` (WARNING).
library;

import 'package:image_picker/image_picker.dart';

final ImagePicker _picker = ImagePicker();

Future<void> bad() async {
  // expect_lint: image_picker_lost_data_empty_check_missing
  final r = await _picker.retrieveLostData();
  final files = r.files;
}

Future<void> good() async {
  final r = await _picker.retrieveLostData();
  if (r.isEmpty) return;
  final files = r.files;
}
