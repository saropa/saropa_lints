// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `flutter_map_deprecated_tile_size` (INFO).
library;

import 'package:flutter_map/flutter_map.dart';

void bad() {
  // expect_lint: flutter_map_deprecated_tile_size
  TileLayer(tileSize: 256.0, userAgentPackageName: 'com.example.app');
}

void good() {
  // The v8 replacement argument — int tile dimension.
  TileLayer(tileDimension: 256, userAgentPackageName: 'com.example.app');
}
