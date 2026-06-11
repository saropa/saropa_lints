// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `youtube_player_convert_url_unchecked` (WARNING).
library;

import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void bad(String url) {
  // expect_lint: youtube_player_convert_url_unchecked
  final String id = YoutubePlayerController.convertUrlToId(url)!;
}

void good(String url) {
  final String? id = YoutubePlayerController.convertUrlToId(url);
  if (id == null) return;
  final String safe = id;
}
