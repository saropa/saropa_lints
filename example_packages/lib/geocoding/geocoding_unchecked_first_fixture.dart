// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `geocoding_unchecked_first` (ERROR).
library;

import 'package:geocoding/geocoding.dart';

Future<void> bad() async {
  // expect_lint: geocoding_unchecked_first
  final loc = (await locationFromAddress('q')).first;
}

Future<void> good() async {
  final results = await locationFromAddress('q');
  if (results.isEmpty) return;
  final loc = results.first;
}
