// ignore_for_file: unused_local_variable, unused_element, unawaited_futures
// ignore_for_file: avoid_print, unused_field, avoid_types_on_closure_parameters
// ignore_for_file: use_of_void_result
// Test fixture for async rules added in v2.3.10

import 'dart:async';

// =========================================================================
// avoid_future_then_in_async
// =========================================================================
// Warns when .then() is used inside an async function.

// BAD: Using .then() inside async function
Future<void> badFutureThenInAsync() async {
  // expect_lint: avoid_future_then_in_async
  fetchData().then((data) {
    processData(data);
  });
}

// BAD: Nested .then() in async function
Future<void> badNestedThenInAsync() async {
  // expect_lint: avoid_future_then_in_async
  fetchData().then((data) {
    return processData(data);
  }).then((result) {
    print(result);
  });
}

// GOOD: Using await instead of .then()
Future<void> goodUsingAwait() async {
  final data = await fetchData();
  processData(data);
}

// GOOD: Using .then() outside async function (sync function)
void goodThenInSyncFunction() {
  fetchData().then((data) {
    processData(data);
  });
}

// =========================================================================
// avoid_unawaited_future
// =========================================================================
// Warns when a Future is not awaited and not explicitly marked.

// BAD: Unawaited future in statement
void badUnawaitedFuture() {
  // expect_lint: avoid_unawaited_future
  saveData();
}

// BAD: Unawaited future in async function
Future<void> badUnawaitedFutureInAsync() async {
  // expect_lint: avoid_unawaited_future
  saveData();
}

// GOOD: Awaited future
Future<void> goodAwaitedFuture() async {
  await saveData();
}

// GOOD: Explicitly fire-and-forget with unawaited()
void goodUnawaitedExplicit() {
  unawaited(saveData());
}

// GOOD: Assigning future to variable (intentional)
void goodAssigningFuture() {
  final Future<void> future = saveData();
  // Will handle later
}

// =========================================================================
// avoid_unawaited_future - Safe fire-and-forget patterns (no lint expected)
// =========================================================================

// GOOD: cancel() in dispose() - sync method, widget is being destroyed
class MyWidget {
  StreamSubscription<int>? _subscription;

  void dispose() {
    _subscription?.cancel();
  }
}

// GOOD: .catchError() chain - errors are explicitly handled
class AnimationExample {
  final _scrollController = _MockScrollController();

  void scrollToPosition() {
    _scrollController
        .animateTo(100)
        .catchError((Object error, StackTrace stack) {});
  }
}

// GOOD: .ignore() - explicitly marked as fire-and-forget
void goodFutureIgnore() {
  saveData().ignore();
}

// BAD: cancel() outside dispose() - still needs explicit handling
void badCancelOutsideDispose() {
  StreamSubscription<int>? subscription;
  // expect_lint: avoid_unawaited_future
  subscription?.cancel();
}

// =========================================================================
// Stream Rules (from v4.1.4)
// =========================================================================

class StreamTestWidget extends StatefulWidget {
  const StreamTestWidget({super.key});

  @override
  State<StreamTestWidget> createState() => _StreamTestWidgetState();
}

class _StreamTestWidgetState extends State<StreamTestWidget> {
  late StreamController<int> _controller;

  @override
  void initState() {
    super.initState();
    _controller = StreamController<int>();

    // expect_lint: prefer_stream_distinct
    _controller.stream.listen((value) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => Container();
}

class StreamDistinctFalsePositiveWidget extends StatefulWidget {
  const StreamDistinctFalsePositiveWidget({super.key});

  @override
  State<StreamDistinctFalsePositiveWidget> createState() =>
      _StreamDistinctFalsePositiveWidgetState();
}

class _StreamDistinctFalsePositiveWidgetState
    extends State<StreamDistinctFalsePositiveWidget> {
  @override
  void initState() {
    super.initState();

    // OK: Stream<void>.periodic — .distinct() would break the timer
    Stream<void>.periodic(const Duration(seconds: 1)).listen((_) {
      setState(() {});
    });

    // OK: .distinct() already present in chain before .map()
    StreamController<int>().stream.distinct().map((v) => v + 1).listen((v) {
      setState(() {});
    });

    // OK: .distinct() already present in chain before .where()
    StreamController<int>().stream.distinct().where((v) => v > 0).listen((v) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => Container();
}

void testBroadcastStream() {
  final controller = StreamController<int>();
  final stream = controller.stream;

  // BAD: Multiple listen on single-subscription stream
  // expect_lint: prefer_broadcast_stream
  stream.listen(print);
  stream.listen(print);

  // GOOD: Use broadcast
  final broadcastStream = controller.stream.asBroadcastStream();
  broadcastStream.listen(print);
  broadcastStream.listen(print);
}

// =========================================================================
// Async/Build Rules (from v4.1.4)
// =========================================================================

class BadAsyncWidget extends StatelessWidget {
  const BadAsyncWidget({super.key});

  // expect_lint: avoid_async_in_build
  @override
  Future<Widget> build(BuildContext context) async {
    return Container();
  }
}

class BadFutureInBuildWidget extends StatelessWidget {
  const BadFutureInBuildWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_future_in_build
    return FutureBuilder(
      future: fetchDataForWidget(),
      builder: (context, snapshot) => Container(),
    );
  }

  Future<String> fetchDataForWidget() async => 'data';
}

class BadMountedCheckWidget extends StatefulWidget {
  const BadMountedCheckWidget({super.key});

  @override
  State<BadMountedCheckWidget> createState() => _BadMountedCheckWidgetState();
}

class _BadMountedCheckWidgetState extends State<BadMountedCheckWidget> {
  String _data = '';

  Future<void> loadData() async {
    final data = await fetchDataForWidget();
    // expect_lint: require_mounted_check_after_await
    setState(() => _data = data);
  }

  Future<String> fetchDataForWidget() async => 'data';

  @override
  Widget build(BuildContext context) => Text(_data);
}

// GOOD: With mounted check
class GoodMountedCheckWidget extends StatefulWidget {
  const GoodMountedCheckWidget({super.key});

  @override
  State<GoodMountedCheckWidget> createState() => _GoodMountedCheckWidgetState();
}

class _GoodMountedCheckWidgetState extends State<GoodMountedCheckWidget> {
  String _data = '';

  Future<void> loadData() async {
    final data = await fetchDataForWidget();
    if (!mounted) return;
    setState(() => _data = data);
  }

  Future<String> fetchDataForWidget() async => 'data';

  @override
  Widget build(BuildContext context) => Text(_data);
}

// =========================================================================
// Helper mocks
// =========================================================================

Future<String> fetchData() async => 'data';
void processData(String data) {}
Future<void> saveData() async {}
void unawaited(Future<void> future) {}

class _MockScrollController {
  Future<void> animateTo(double offset) async {}
}

extension FutureIgnoreExtension<T> on Future<T> {
  void ignore() {}
}

// Flutter mocks for async rules
abstract class StatelessWidget {
  const StatelessWidget({this.key});
  final Object? key;
  Widget build(BuildContext context);
}

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
  Widget build(BuildContext context);
}

class BuildContext {}

class Widget {}

class Container extends Widget {}

class Text extends Widget {
  Text(this.data);
  final String data;
}

class FutureBuilder<T> extends Widget {
  FutureBuilder({required this.future, required this.builder});
  final Future<T> future;
  final Widget Function(BuildContext, dynamic) builder;
}

// =========================================================================
// Async Rules (from v4.1.7)
// =========================================================================

// BAD: WebSocket without reconnection handling
class BadWebSocketService {
  // expect_lint: require_websocket_reconnection
  WebSocketDemo? _channel;

  void connect() {
    _channel = WebSocketDemo.connect('wss://example.com');
  }
}

// GOOD: WebSocket with reconnection logic
class GoodWebSocketService {
  WebSocketDemo? _channel;
  int _reconnectAttempts = 0;

  void connect() {
    _channel = WebSocketDemo.connect('wss://example.com');
    _channel!.stream.listen(
      (data) {},
      onDone: _handleReconnect,
      onError: (error) => _handleReconnect(),
    );
  }

  void _handleReconnect() {
    if (_reconnectAttempts < 5) {
      _reconnectAttempts++;
      connect();
    }
  }
}

// BAD: Heavy computation on main isolate
void processLargeDataBad(List<int> data) {
  // expect_lint: prefer_isolate_for_heavy_compute
  for (var i = 0; i < 1000000; i++) {
    // Heavy computation
  }
}

// GOOD: Heavy computation on separate isolate
Future<void> processLargeDataGood(List<int> data) async {
  await computeDemo(() {
    for (var i = 0; i < 1000000; i++) {
      // Heavy computation
    }
  });
}

// BAD: Caching without TTL
class BadCacheService {
  // expect_lint: require_cache_ttl
  final Map<String, Object> _cache = {};

  void set(String key, Object value) {
    _cache[key] = value;
  }
}

// GOOD: Caching with TTL
class GoodCacheService {
  final Map<String, CacheEntryDemo> _cache = {};
  final Duration ttl = Duration(minutes: 5);

  void set(String key, Object value) {
    _cache[key] = CacheEntryDemo(value, DateTime.now().add(ttl));
  }

  Object? get(String key) {
    final entry = _cache[key];
    if (entry != null && entry.expiry.isAfter(DateTime.now())) {
      return entry.value;
    }
    _cache.remove(key);
    return null;
  }
}

// Mock classes
class WebSocketDemo {
  static WebSocketDemo connect(String url) => WebSocketDemo._();
  WebSocketDemo._();
  StreamDemo get stream => StreamDemo();
}

class StreamDemo {
  void listen(
    void Function(dynamic)? onData, {
    void Function()? onDone,
    void Function(Object)? onError,
  }) {}
}

Future<T> computeDemo<T>(T Function() callback) async => callback();

class CacheEntryDemo {
  CacheEntryDemo(this.value, this.expiry);
  final Object value;
  final DateTime expiry;
}
