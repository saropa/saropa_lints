// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `flutter_map_missing_user_agent` (WARNING).
library;

import 'package:flutter_map/flutter_map.dart';

void bad() {
  // expect_lint: flutter_map_missing_user_agent
  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
}

void good() {
  // Real bundle id supplied — OSM can identify the traffic.
  TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.example.app',
  );

  // Asset provider never hits the network, so the policy does not apply.
  TileLayer(tileProvider: AssetTileProvider());
}
