// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `youtube_player_auto_fullscreen_without_portrait_guard` (INFO).
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class BadPlayerState extends State<StatefulWidget> {
  late final YoutubePlayerController controller;

  @override
  Widget build(BuildContext context) {
    // expect_lint: youtube_player_auto_fullscreen_without_portrait_guard
    return YoutubePlayer(controller: controller);
  }
}

class GoodPlayerState extends State<StatefulWidget> {
  late final YoutubePlayerController controller;

  @override
  void dispose() {
    // Restoring orientation on teardown suppresses the report.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(controller: controller, autoFullScreen: false);
  }
}
