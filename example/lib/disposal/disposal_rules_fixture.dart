// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: unused_field, require_dispose, avoid_undisposed_instances
// Test fixture for disposal rules

import 'dart:async';

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

// GOOD: TextEditingController from external source (e.g., Autocomplete callback)
// This should NOT trigger the lint - the external widget owns the controller
class ExternalControllerWidget extends StatefulWidget {
  const ExternalControllerWidget({super.key});

  @override
  State<ExternalControllerWidget> createState() =>
      _ExternalControllerWidgetState();
}

class _ExternalControllerWidgetState extends State<ExternalControllerWidget> {
  // No lint expected - controller is assigned from external source, not created here
  TextEditingController? _autocompleteController;

  @override
  void dispose() {
    // No need to dispose - external widget owns it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) =>
          const Iterable<String>.empty(),
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController controller,
        FocusNode focusNode,
        VoidCallback onSubmitted,
      ) {
        _autocompleteController = controller; // Assigned, not created
        return TextField(controller: controller, focusNode: focusNode);
      },
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

// =========================================================================
// require_stream_subscription_cancel
// =========================================================================
// Warns when StreamSubscription is not cancelled in dispose().
// Supports both single subscriptions and collections of subscriptions.

// BAD: Single StreamSubscription not cancelled
class BadSingleSubscriptionWidget extends StatefulWidget {
  const BadSingleSubscriptionWidget({super.key});

  @override
  State<BadSingleSubscriptionWidget> createState() =>
      _BadSingleSubscriptionWidgetState();
}

// expect_lint: require_stream_subscription_cancel
class _BadSingleSubscriptionWidgetState
    extends State<BadSingleSubscriptionWidget> {
  StreamSubscription<int>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Stream.periodic(
      const Duration(seconds: 1),
      (i) => i,
    ).listen((data) => setState(() {}));
  }

  // Missing cancel!

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Single StreamSubscription cancelled with ?.cancel()
class GoodSingleSubscriptionWidget extends StatefulWidget {
  const GoodSingleSubscriptionWidget({super.key});

  @override
  State<GoodSingleSubscriptionWidget> createState() =>
      _GoodSingleSubscriptionWidgetState();
}

class _GoodSingleSubscriptionWidgetState
    extends State<GoodSingleSubscriptionWidget> {
  StreamSubscription<int>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Stream.periodic(
      const Duration(seconds: 1),
      (i) => i,
    ).listen((data) => setState(() {}));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Single StreamSubscription cancelled with .cancel()
class GoodSingleSubscriptionNonNullWidget extends StatefulWidget {
  const GoodSingleSubscriptionNonNullWidget({super.key});

  @override
  State<GoodSingleSubscriptionNonNullWidget> createState() =>
      _GoodSingleSubscriptionNonNullWidgetState();
}

class _GoodSingleSubscriptionNonNullWidgetState
    extends State<GoodSingleSubscriptionNonNullWidget> {
  late StreamSubscription<int> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Stream.periodic(
      const Duration(seconds: 1),
      (i) => i,
    ).listen((data) => setState(() {}));
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// BAD: Collection of StreamSubscriptions not cancelled
class BadCollectionSubscriptionWidget extends StatefulWidget {
  const BadCollectionSubscriptionWidget({super.key});

  @override
  State<BadCollectionSubscriptionWidget> createState() =>
      _BadCollectionSubscriptionWidgetState();
}

// expect_lint: require_stream_subscription_cancel
class _BadCollectionSubscriptionWidgetState
    extends State<BadCollectionSubscriptionWidget> {
  final List<StreamSubscription<void>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      Stream.periodic(const Duration(seconds: 1)).listen((_) {}),
    );
  }

  // Missing cancel!

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Collection cancelled with for-in loop
class GoodCollectionForInWidget extends StatefulWidget {
  const GoodCollectionForInWidget({super.key});

  @override
  State<GoodCollectionForInWidget> createState() =>
      _GoodCollectionForInWidgetState();
}

class _GoodCollectionForInWidgetState extends State<GoodCollectionForInWidget> {
  final List<StreamSubscription<void>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      Stream.periodic(const Duration(seconds: 1)).listen((_) {}),
    );
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Collection cancelled with for-in loop (typed)
class GoodCollectionForInTypedWidget extends StatefulWidget {
  const GoodCollectionForInTypedWidget({super.key});

  @override
  State<GoodCollectionForInTypedWidget> createState() =>
      _GoodCollectionForInTypedWidgetState();
}

class _GoodCollectionForInTypedWidgetState
    extends State<GoodCollectionForInTypedWidget> {
  final List<StreamSubscription<void>> _activeSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _activeSubscriptions.add(
      Stream.periodic(const Duration(seconds: 1)).listen((_) {}),
    );
  }

  @override
  void dispose() {
    for (final StreamSubscription<void> subscription in _activeSubscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Collection cancelled with forEach
class GoodCollectionForEachWidget extends StatefulWidget {
  const GoodCollectionForEachWidget({super.key});

  @override
  State<GoodCollectionForEachWidget> createState() =>
      _GoodCollectionForEachWidgetState();
}

class _GoodCollectionForEachWidgetState
    extends State<GoodCollectionForEachWidget> {
  final List<StreamSubscription<void>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      Stream.periodic(const Duration(seconds: 1)).listen((_) {}),
    );
  }

  @override
  void dispose() {
    _subscriptions.forEach((s) => s.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Set of StreamSubscriptions cancelled
class GoodSetSubscriptionWidget extends StatefulWidget {
  const GoodSetSubscriptionWidget({super.key});

  @override
  State<GoodSetSubscriptionWidget> createState() =>
      _GoodSetSubscriptionWidgetState();
}

class _GoodSetSubscriptionWidgetState extends State<GoodSetSubscriptionWidget> {
  final Set<StreamSubscription<void>> _subscriptions = {};

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      Stream.periodic(const Duration(seconds: 1)).listen((_) {}),
    );
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Mixed single + collection subscriptions
class GoodMixedSubscriptionWidget extends StatefulWidget {
  const GoodMixedSubscriptionWidget({super.key});

  @override
  State<GoodMixedSubscriptionWidget> createState() =>
      _GoodMixedSubscriptionWidgetState();
}

class _GoodMixedSubscriptionWidgetState
    extends State<GoodMixedSubscriptionWidget> {
  StreamSubscription<int>? _singleSub;
  final List<StreamSubscription<void>> _multiSubs = [];

  @override
  void initState() {
    super.initState();
    _singleSub = Stream.periodic(const Duration(seconds: 1), (i) => i)
        .listen((data) => setState(() {}));
    _multiSubs.add(
      Stream.periodic(const Duration(seconds: 2)).listen((_) {}),
    );
  }

  @override
  void dispose() {
    _singleSub?.cancel();
    for (final sub in _multiSubs) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}
