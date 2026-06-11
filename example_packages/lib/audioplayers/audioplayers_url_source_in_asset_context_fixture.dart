// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `audioplayers_url_source_in_asset_context` (WARNING).
library;

import 'package:audioplayers/audioplayers.dart';

Future<void> bad() async {
  final player = AudioPlayer();
  // expect_lint: audioplayers_url_source_in_asset_context
  await player.play(UrlSource('assets/sounds/click.wav'));
}

Future<void> good() async {
  // A genuine http(s) URL containing /assets/ is a real remote stream.
  final player = AudioPlayer();
  await player.play(UrlSource('https://cdn.example.com/assets/click.wav'));
  // Bundled audio uses AssetSource (no assets/ prefix).
  await player.play(AssetSource('sounds/click.wav'));
}
