// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `audioplayers_release_mode_loop_with_complete_listener` (INFO).
library;

import 'package:audioplayers/audioplayers.dart';

Future<void> bad() async {
  final player = AudioPlayer();
  await player.setReleaseMode(ReleaseMode.loop);
  // expect_lint: audioplayers_release_mode_loop_with_complete_listener
  player.onPlayerComplete.listen((void _) {});
}

Future<void> good() async {
  // ReleaseMode.stop fires onPlayerComplete — the listener is live.
  final player = AudioPlayer();
  await player.setReleaseMode(ReleaseMode.stop);
  player.onPlayerComplete.listen((void _) {});
}
