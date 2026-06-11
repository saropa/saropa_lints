// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `flutter_map_legacy_map_options_center` (WARNING).
library;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void bad() {
  // expect_lint: flutter_map_legacy_map_options_center
  MapOptions(center: const LatLng(0, 0), zoom: 5);
}

void good() {
  // The v6 initial-camera argument names.
  MapOptions(initialCenter: const LatLng(0, 0), initialZoom: 5);
}
