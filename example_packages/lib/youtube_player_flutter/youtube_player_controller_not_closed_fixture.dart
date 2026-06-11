// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `youtube_player_controller_not_closed` (WARNING).
library;

import 'package:flutter/widgets.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class BadState extends State<StatefulWidget> {
  // expect_lint: youtube_player_controller_not_closed
  final YoutubePlayerController controller = YoutubePlayerController();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class GoodState extends State<StatefulWidget> {
  final YoutubePlayerController controller = YoutubePlayerController();

  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
