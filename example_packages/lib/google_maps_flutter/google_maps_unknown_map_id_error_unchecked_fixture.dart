// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `google_maps_unknown_map_id_error_unchecked` (INFO).
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<void> bad(GoogleMapController controller, MarkerId id) async {
  // expect_lint: google_maps_unknown_map_id_error_unchecked
  await controller.showMarkerInfoWindow(id);
}

Future<void> good(GoogleMapController controller, MarkerId id) async {
  // Near-miss: wrapped in a try/catch — must NOT trigger.
  try {
    await controller.showMarkerInfoWindow(id);
  } on Object {
    // ignore unknown map object id
  }
}
