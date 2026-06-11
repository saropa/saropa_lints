// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `geocoding_concurrent_locale_race`.
library;

import 'package:geocoding/geocoding.dart';

Future<void> bad(List<String> locales) async {
  for (final l in locales) {
    // expect_lint: geocoding_concurrent_locale_race
    await setLocaleIdentifier(l);
    await placemarkFromCoordinates(0, 0);
  }
}
