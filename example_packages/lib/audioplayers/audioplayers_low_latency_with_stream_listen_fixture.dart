// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `audioplayers_low_latency_with_stream_listen` (WARNING).
library;

import 'package:audioplayers/audioplayers.dart';

Future<void> bad() async {
  final player = AudioPlayer();
  await player.setPlayerMode(PlayerMode.lowLatency);
  // expect_lint: audioplayers_low_latency_with_stream_listen
  player.onPositionChanged.listen((Duration p) {});
}

Future<void> good() async {
  // mediaPlayer mode emits these events — the listener is live.
  final player = AudioPlayer();
  await player.setPlayerMode(PlayerMode.mediaPlayer);
  player.onPositionChanged.listen((Duration p) {});
}
