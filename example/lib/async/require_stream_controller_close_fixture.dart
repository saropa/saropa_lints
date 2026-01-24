// ignore_for_file: unused_field, unused_element
// Test fixture for require_stream_controller_close rule
// Tests false positive fix for wrapper classes (e.g., IsarStreamController)

import 'dart:async';

// =========================================================================
// MOCK: Flutter framework classes
// =========================================================================

abstract class StatefulWidget {
  const StatefulWidget({this.key});
  final Object? key;
  State createState();
}

abstract class State<T extends StatefulWidget> {
  T get widget => throw UnimplementedError();
  bool get mounted => true;
  void setState(void Function() fn) {}
  void initState() {}
  void dispose() {}
  Widget build(BuildContext context);
}

class BuildContext {}

class Widget {}

class Container extends Widget {}

// =========================================================================
// MOCK: Wrapper class that internally closes StreamController
// =========================================================================

class IsarStreamController<T> {
  final StreamController<List<T>?> _controller =
      StreamController<List<T>?>.broadcast();
  bool _isDisposed = false;
  Timer? _debounceTimer;

  Stream<List<T>?> get stream => _controller.stream;

  void add(List<T>? data) {
    if (!_isDisposed) {
      _controller.add(data);
    }
  }

  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _controller.close(); // The internal StreamController IS closed here
  }
}

// =========================================================================
// BAD: Actual StreamController without close()
// =========================================================================
// SHOULD trigger lint

class BadWidgetWithStreamController extends StatefulWidget {
  const BadWidgetWithStreamController({super.key});

  @override
  State<BadWidgetWithStreamController> createState() =>
      _BadWidgetWithStreamControllerState();
}

class _BadWidgetWithStreamControllerState
    extends State<BadWidgetWithStreamController> {
  // expect_lint: require_stream_controller_close
  final StreamController<String> _controller = StreamController<String>();

  @override
  void dispose() {
    // Missing _controller.close() - should trigger lint!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// GOOD: Actual StreamController with close()
// =========================================================================
// Should NOT trigger lint

class GoodWidgetWithStreamController extends StatefulWidget {
  const GoodWidgetWithStreamController({super.key});

  @override
  State<GoodWidgetWithStreamController> createState() =>
      _GoodWidgetWithStreamControllerState();
}

class _GoodWidgetWithStreamControllerState
    extends State<GoodWidgetWithStreamController> {
  final StreamController<String> _controller = StreamController<String>();

  @override
  void dispose() {
    _controller.close(); // Properly closed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// GOOD: Wrapper class with dispose() that internally closes
// =========================================================================
// Should NOT trigger lint (false positive fix)

class GoodWidgetWithWrapperController extends StatefulWidget {
  const GoodWidgetWithWrapperController({super.key});

  @override
  State<GoodWidgetWithWrapperController> createState() =>
      _GoodWidgetWithWrapperControllerState();
}

class _GoodWidgetWithWrapperControllerState
    extends State<GoodWidgetWithWrapperController> {
  late IsarStreamController<String> _isarController;

  @override
  void initState() {
    super.initState();
    _isarController = IsarStreamController<String>();
  }

  @override
  void dispose() {
    _isarController.dispose(); // Wrapper's dispose() closes internal stream
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// BAD: Wrapper class without dispose() or close()
// =========================================================================
// SHOULD trigger lint

class BadWidgetWithWrapperNoDispose extends StatefulWidget {
  const BadWidgetWithWrapperNoDispose({super.key});

  @override
  State<BadWidgetWithWrapperNoDispose> createState() =>
      _BadWidgetWithWrapperNoDisposeState();
}

class _BadWidgetWithWrapperNoDisposeState
    extends State<BadWidgetWithWrapperNoDispose> {
  // expect_lint: require_stream_controller_close
  late IsarStreamController<String> _isarController;

  @override
  void initState() {
    super.initState();
    _isarController = IsarStreamController<String>();
  }

  @override
  void dispose() {
    // Missing _isarController.dispose() - should trigger lint!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// GOOD: Wrapper class with close() (alternative pattern)
// =========================================================================
// Should NOT trigger lint

class CustomStreamController<T> {
  final StreamController<T> _inner = StreamController<T>();

  Stream<T> get stream => _inner.stream;

  void close() {
    _inner.close();
  }
}

class GoodWidgetWithWrapperClose extends StatefulWidget {
  const GoodWidgetWithWrapperClose({super.key});

  @override
  State<GoodWidgetWithWrapperClose> createState() =>
      _GoodWidgetWithWrapperCloseState();
}

class _GoodWidgetWithWrapperCloseState
    extends State<GoodWidgetWithWrapperClose> {
  late CustomStreamController<int> _customController;

  @override
  void initState() {
    super.initState();
    _customController = CustomStreamController<int>();
  }

  @override
  void dispose() {
    _customController.close(); // Using close() instead of dispose()
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// EDGE CASE: Multiple controllers (mixed exact and wrapper types)
// =========================================================================
// Should only trigger for the exact StreamController without close()

class MixedControllersWidget extends StatefulWidget {
  const MixedControllersWidget({super.key});

  @override
  State<MixedControllersWidget> createState() => _MixedControllersWidgetState();
}

class _MixedControllersWidgetState extends State<MixedControllersWidget> {
  // expect_lint: require_stream_controller_close
  final StreamController<int> _exactController = StreamController<int>();
  late IsarStreamController<String> _wrapperController;

  @override
  void initState() {
    super.initState();
    _wrapperController = IsarStreamController<String>();
  }

  @override
  void dispose() {
    // Only disposes wrapper, but exact StreamController needs close()
    _wrapperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// GOOD: Multiple controllers all properly cleaned up
// =========================================================================

class GoodMixedControllersWidget extends StatefulWidget {
  const GoodMixedControllersWidget({super.key});

  @override
  State<GoodMixedControllersWidget> createState() =>
      _GoodMixedControllersWidgetState();
}

class _GoodMixedControllersWidgetState
    extends State<GoodMixedControllersWidget> {
  final StreamController<int> _exactController = StreamController<int>();
  late IsarStreamController<String> _wrapperController;

  @override
  void initState() {
    super.initState();
    _wrapperController = IsarStreamController<String>();
  }

  @override
  void dispose() {
    _exactController.close(); // Exact type closed
    _wrapperController.dispose(); // Wrapper disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// GOOD: StreamController closed inside try-catch
// =========================================================================
// Should NOT trigger lint - proves try-catch wrapping works

class TryCatchCloseWidget extends StatefulWidget {
  const TryCatchCloseWidget({super.key});

  @override
  State<TryCatchCloseWidget> createState() => _TryCatchCloseWidgetState();
}

class _TryCatchCloseWidgetState extends State<TryCatchCloseWidget> {
  final StreamController<String> _controller = StreamController<String>();

  @override
  void dispose() {
    try {
      _controller.close();
    } catch (e) {
      // Handle error
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// GOOD: StreamController with record type parameter
// =========================================================================
// Should NOT trigger lint - proves record types work

class RecordTypeControllerWidget extends StatefulWidget {
  const RecordTypeControllerWidget({super.key});

  @override
  State<RecordTypeControllerWidget> createState() =>
      _RecordTypeControllerWidgetState();
}

class _RecordTypeControllerWidgetState
    extends State<RecordTypeControllerWidget> {
  final StreamController<(double speed, double progress)> _progressController =
      StreamController<(double speed, double progress)>.broadcast();

  @override
  void dispose() {
    _progressController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// GOOD: StreamController closed inside conditional
// =========================================================================
// Should NOT trigger lint

class ConditionalCloseWidget extends StatefulWidget {
  const ConditionalCloseWidget({super.key});

  @override
  State<ConditionalCloseWidget> createState() => _ConditionalCloseWidgetState();
}

class _ConditionalCloseWidgetState extends State<ConditionalCloseWidget> {
  final StreamController<int> _controller = StreamController<int>();
  bool _shouldClose = true;

  @override
  void dispose() {
    if (_shouldClose) {
      _controller.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container();
}
