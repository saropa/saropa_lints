// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `geocoding_deprecated_locale_param` (ERROR).
library;

import 'package:geocoding/geocoding.dart';

Future<void> bad() async {
  // expect_lint: geocoding_deprecated_locale_param
  await locationFromAddress('q', localeIdentifier: 'fr');
}
