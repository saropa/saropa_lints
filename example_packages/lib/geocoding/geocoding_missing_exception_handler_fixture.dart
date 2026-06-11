// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `geocoding_missing_exception_handler`.
library;

import 'package:geocoding/geocoding.dart';

Future<void> bad() async {
  // expect_lint: geocoding_missing_exception_handler
  final r = await locationFromAddress('q');
}

Future<void> good() async {
  try {
    final r = await locationFromAddress('q');
  } on Exception catch (e) {}
}
