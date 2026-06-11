// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `google_maps_set_map_style_deprecated` (WARNING).
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<void> bad(GoogleMapController controller, String styleJson) async {
  // expect_lint: google_maps_set_map_style_deprecated
  await controller.setMapStyle(styleJson);
}

GoogleMap good(String styleJson) {
  // Near-miss: passing style: to the widget is the recommended replacement.
  return GoogleMap(
    initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
    style: styleJson,
  );
}
