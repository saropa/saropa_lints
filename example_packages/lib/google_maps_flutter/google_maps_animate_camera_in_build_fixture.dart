// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `google_maps_animate_camera_in_build` (ERROR).
library;

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class _BadMap extends StatelessWidget {
  const _BadMap({required this.controller, required this.update});

  final GoogleMapController controller;
  final CameraUpdate update;

  @override
  Widget build(BuildContext context) {
    // expect_lint: google_maps_animate_camera_in_build
    controller.animateCamera(update);
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
    );
  }
}

class _GoodMap extends StatelessWidget {
  const _GoodMap({required this.controller, required this.update});

  final GoogleMapController controller;
  final CameraUpdate update;

  @override
  Widget build(BuildContext context) {
    // Near-miss: the camera move lives in an event handler, not build() — OK.
    return GestureDetector(
      onTap: () => controller.animateCamera(update),
      child: GoogleMap(
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
      ),
    );
  }
}
