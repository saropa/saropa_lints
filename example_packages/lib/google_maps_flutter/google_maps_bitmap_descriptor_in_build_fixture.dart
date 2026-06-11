// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `google_maps_bitmap_descriptor_in_build` (WARNING).
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class _BadMarkerIcon extends StatelessWidget {
  const _BadMarkerIcon({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    // expect_lint: google_maps_bitmap_descriptor_in_build
    final BitmapDescriptor icon = BitmapDescriptor.fromBytes(bytes);
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
      markers: <Marker>{Marker(markerId: const MarkerId('a'), icon: icon)},
    );
  }
}

class _GoodMarkerIcon extends StatefulWidget {
  const _GoodMarkerIcon({required this.bytes});

  final Uint8List bytes;

  @override
  State<_GoodMarkerIcon> createState() => _GoodMarkerIconState();
}

class _GoodMarkerIconState extends State<_GoodMarkerIcon> {
  late final BitmapDescriptor _icon;

  @override
  void initState() {
    super.initState();
    // Near-miss: building the descriptor once in initState() must NOT trigger.
    _icon = BitmapDescriptor.fromBytes(widget.bytes);
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
      markers: <Marker>{Marker(markerId: const MarkerId('a'), icon: _icon)},
    );
  }
}
