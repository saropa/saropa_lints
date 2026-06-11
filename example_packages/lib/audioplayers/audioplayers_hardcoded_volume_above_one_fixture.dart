// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `audioplayers_hardcoded_volume_above_one` (WARNING).
library;

import 'package:audioplayers/audioplayers.dart';

Future<void> bad() async {
  final player = AudioPlayer();
  // expect_lint: audioplayers_hardcoded_volume_above_one
  await player.setVolume(100);
}

Future<void> good() async {
  // In-range literal, and a non-literal variable is never flagged.
  final player = AudioPlayer();
  await player.setVolume(1.0);
  final double v = computeVolume();
  await player.setVolume(v);
}

double computeVolume() => 0.5;
