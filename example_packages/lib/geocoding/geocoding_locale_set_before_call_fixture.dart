// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `geocoding_locale_set_before_call` (INFO).
library;

import 'package:geocoding/geocoding.dart';

Future<void> bad() async {
  // expect_lint: geocoding_locale_set_before_call
  final r = await locationFromAddress('q');
}

Future<void> good() async {
  await setLocaleIdentifier('fr');
  final r = await locationFromAddress('q');
}
