// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `google_maps_markers_rebuilt_in_build` (WARNING).
library;

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class _BadMap extends StatelessWidget {
  const _BadMap();

  @override
  Widget build(BuildContext context) {
    // expect_lint: google_maps_markers_rebuilt_in_build
    final Set<Marker> markers = <Marker>{
      const Marker(markerId: MarkerId('a')),
    };
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
      markers: markers,
    );
  }
}

class _GoodMap extends StatelessWidget {
  const _GoodMap({required this.markers});

  // Set held outside build(), passed in — no per-frame allocation.
  final Set<Marker> markers;

  @override
  Widget build(BuildContext context) {
    // Near-miss: a const empty set is zero-overhead and must NOT trigger.
    const Set<Marker> empty = <Marker>{};
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
      markers: markers,
    );
  }
}
