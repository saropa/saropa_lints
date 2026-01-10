// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: unused_field, require_dispose, avoid_undisposed_instances
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
  // Note: VideoPlayerController test requires video_player package
  // The general require_dispose rule covers this case
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

// =========================================================================
// require_text_editing_controller_dispose
// =========================================================================

// BAD: TextEditingController not disposed
class BadFormWidget extends StatefulWidget {
  const BadFormWidget({super.key});

  @override
  State<BadFormWidget> createState() => _BadFormWidgetState();
}

class _BadFormWidgetState extends State<BadFormWidget> {
  // expect_lint: require_text_editing_controller_dispose
  final TextEditingController _emailController = TextEditingController();
  // expect_lint: require_text_editing_controller_dispose
  final TextEditingController _passwordController = TextEditingController();

  // Missing dispose!

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: _emailController),
        TextField(controller: _passwordController),
      ],
    );
  }
}

// GOOD: TextEditingController properly disposed
class GoodFormWidget extends StatefulWidget {
  const GoodFormWidget({super.key});

  @override
  State<GoodFormWidget> createState() => _GoodFormWidgetState();
}

class _GoodFormWidgetState extends State<GoodFormWidget> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: _emailController),
        TextField(controller: _passwordController),
      ],
    );
  }
}

// =========================================================================
// require_page_controller_dispose
// =========================================================================

// BAD: PageController not disposed
class BadPageViewWidget extends StatefulWidget {
  const BadPageViewWidget({super.key});

  @override
  State<BadPageViewWidget> createState() => _BadPageViewWidgetState();
}

class _BadPageViewWidgetState extends State<BadPageViewWidget> {
  // expect_lint: require_page_controller_dispose
  final PageController _pageController = PageController();

  // Missing dispose!

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      children: const [
        Text('Page 1'),
        Text('Page 2'),
        Text('Page 3'),
      ],
    );
  }
}

// GOOD: PageController properly disposed
class GoodPageViewWidget extends StatefulWidget {
  const GoodPageViewWidget({super.key});

  @override
  State<GoodPageViewWidget> createState() => _GoodPageViewWidgetState();
}

class _GoodPageViewWidgetState extends State<GoodPageViewWidget> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      children: const [
        Text('Page 1'),
        Text('Page 2'),
        Text('Page 3'),
      ],
    );
  }
}
