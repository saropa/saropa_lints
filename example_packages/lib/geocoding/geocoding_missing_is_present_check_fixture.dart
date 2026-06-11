// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `geocoding_missing_is_present_check` (INFO).
library;

import 'package:geocoding/geocoding.dart';

Future<void> bad() async {
  // expect_lint: geocoding_missing_is_present_check
  final r = await placemarkFromCoordinates(0, 0);
}

Future<void> good() async {
  if (await isPresent()) {
    final r = await placemarkFromCoordinates(0, 0);
  }
}
