// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `flutter_map_deprecated_polygon_label_placement` (INFO).
library;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void bad() {
  // expect_lint: flutter_map_deprecated_polygon_label_placement
  Polygon(
    points: const [LatLng(0, 0), LatLng(1, 1), LatLng(2, 0)],
    labelPlacement: PolygonLabelPlacement.centroid,
  );
}

void good() {
  // The v8.2 calculator replacement.
  Polygon(
    points: const [LatLng(0, 0), LatLng(1, 1), LatLng(2, 0)],
    labelPlacementCalculator: const PolygonLabelPlacementCalculator.centroid(),
  );
}
