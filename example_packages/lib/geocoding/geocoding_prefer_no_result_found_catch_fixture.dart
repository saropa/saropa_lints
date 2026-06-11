// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `geocoding_prefer_no_result_found_catch` (INFO).
library;

import 'package:geocoding/geocoding.dart';

Future<void> bad() async {
  try {
    await locationFromAddress('q');
  }
  // expect_lint: geocoding_prefer_no_result_found_catch
  on PlatformException catch (e) {}
}
