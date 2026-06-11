// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `flutter_map_missing_error_tile_callback` (INFO).
library;

import 'package:flutter_map/flutter_map.dart';

void bad() {
  // expect_lint: flutter_map_missing_error_tile_callback
  TileLayer(urlTemplate: 'https://example.com/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.app');
}

void good() {
  // An error callback handles tile-load failures instead of a blank grid.
  TileLayer(
    urlTemplate: 'https://example.com/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.example.app',
    errorTileCallback: (tile, error, stack) {},
  );

  // Asset provider has a different (non-network) failure model — not flagged.
  TileLayer(tileProvider: AssetTileProvider());
}
