// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `google_maps_cloud_map_id_deprecated` (WARNING).
library;

import 'package:google_maps_flutter/google_maps_flutter.dart';

GoogleMap bad() {
  // expect_lint: google_maps_cloud_map_id_deprecated
  return GoogleMap(
    initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
    cloudMapId: 'abc123',
  );
}

GoogleMap good() {
  // Near-miss: the migrated mapId: argument must NOT trigger.
  return GoogleMap(
    initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
    mapId: 'abc123',
  );
}
