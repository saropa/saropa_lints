// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: unused_field
// Test fixture for disposal rules

import 'package:flutter/material.dart';

// =========================================================================
// require_media_player_dispose
// =========================================================================

// BAD: VideoPlayerController not disposed
class BadVideoPlayerWidget extends StatefulWidget {
  const BadVideoPlayerWidget({super.key});

  @override
  State<BadVideoPlayerWidget> createState() => _BadVideoPlayerWidgetState();
}

class _BadVideoPlayerWidgetState extends State<BadVideoPlayerWidget> {
  // expect_lint: require_media_player_dispose
  // late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // _controller = VideoPlayerController.asset('video.mp4');
  }

  // Missing dispose!

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

// GOOD: VideoPlayerController properly disposed
class GoodVideoPlayerWidget extends StatefulWidget {
  const GoodVideoPlayerWidget({super.key});

  @override
  State<GoodVideoPlayerWidget> createState() => _GoodVideoPlayerWidgetState();
}

class _GoodVideoPlayerWidgetState extends State<GoodVideoPlayerWidget> {
  // late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // _controller = VideoPlayerController.asset('video.mp4');
  }

  @override
  void dispose() {
    // _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

// =========================================================================
// require_tab_controller_dispose
// =========================================================================

// BAD: TabController not disposed
class BadTabWidget extends StatefulWidget {
  const BadTabWidget({super.key});

  @override
  State<BadTabWidget> createState() => _BadTabWidgetState();
}

class _BadTabWidgetState extends State<BadTabWidget>
    with SingleTickerProviderStateMixin {
  // expect_lint: require_tab_controller_dispose
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // Missing dispose!

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Tab 1'),
        Tab(text: 'Tab 2'),
        Tab(text: 'Tab 3'),
      ],
    );
  }
}

// GOOD: TabController properly disposed
class GoodTabWidget extends StatefulWidget {
  const GoodTabWidget({super.key});

  @override
  State<GoodTabWidget> createState() => _GoodTabWidgetState();
}

class _GoodTabWidgetState extends State<GoodTabWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Tab 1'),
        Tab(text: 'Tab 2'),
        Tab(text: 'Tab 3'),
      ],
    );
  }
}
