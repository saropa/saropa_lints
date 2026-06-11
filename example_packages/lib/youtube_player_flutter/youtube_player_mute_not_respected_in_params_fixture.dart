// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `youtube_player_mute_not_respected_in_params` (WARNING).
library;

import 'package:youtube_player_flutter/youtube_player_flutter.dart';

YoutubePlayerController bad(String id) {
  // expect_lint: youtube_player_mute_not_respected_in_params
  return YoutubePlayerController.fromVideoId(
    videoId: id,
    autoPlay: true,
    params: const YoutubePlayerParams(mute: false),
  );
}

YoutubePlayerController good(String id) {
  // autoPlay with mute: true respects browser autoplay policy.
  return YoutubePlayerController.fromVideoId(
    videoId: id,
    autoPlay: true,
    params: const YoutubePlayerParams(mute: true),
  );
}
