// ignore_for_file: unused_element

import 'package:geolocator/geolocator.dart';

/// Fixture for `avoid_geolocator_background_without_config`.
Stream<dynamic> badBackgroundStreamWithoutPlistManifest() {
  // LINT: Background stream requires UIBackgroundModes location / Android permission.
  return Geolocator.getPositionStream();
}
