// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `flutter_map_fallback_url_disables_cache` (INFO).
library;

import 'package:flutter_map/flutter_map.dart';

void bad() {
  // expect_lint: flutter_map_fallback_url_disables_cache
  TileLayer(
    urlTemplate: 'https://example.com/{z}/{x}/{y}.png',
    fallbackUrl: 'https://backup.example.com/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.example.app',
  );
}

void good() {
  // No fallbackUrl — in-memory tile caching stays enabled.
  TileLayer(
    urlTemplate: 'https://example.com/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.example.app',
  );

  // Asset provider is not a NetworkTileProvider, so the cache concern is moot.
  TileLayer(
    fallbackUrl: 'unused',
    tileProvider: AssetTileProvider(),
  );
}
