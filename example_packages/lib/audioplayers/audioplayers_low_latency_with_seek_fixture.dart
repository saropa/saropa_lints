// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `audioplayers_low_latency_with_seek` (WARNING).
library;

import 'package:audioplayers/audioplayers.dart';

Future<void> bad() async {
  final player = AudioPlayer();
  await player.setPlayerMode(PlayerMode.lowLatency);
  // expect_lint: audioplayers_low_latency_with_seek
  await player.seek(const Duration(seconds: 5));
}

Future<void> good() async {
  // mediaPlayer mode supports seek — no warning.
  final player = AudioPlayer();
  await player.setPlayerMode(PlayerMode.mediaPlayer);
  await player.seek(const Duration(seconds: 5));
}
