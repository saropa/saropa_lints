// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `youtube_player_scaffold_deprecated` (INFO).
library;

import 'package:flutter/widgets.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

Widget bad(YoutubePlayerController controller) {
  // expect_lint: youtube_player_scaffold_deprecated
  return YoutubePlayerScaffold(
    controller: controller,
    builder: (BuildContext context, Widget player) => player,
  );
}

Widget good(YoutubePlayerController controller) {
  return YoutubePlayer(controller: controller);
}
