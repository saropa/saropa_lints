// ignore_for_file: unused_local_variable, unused_element, unawaited_futures
// ignore_for_file: avoid_print, unused_field, avoid_types_on_closure_parameters
// ignore_for_file: use_of_void_result
// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters, override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
// ignore_for_file: non_abstract_class_inherits_abstract_member, extends_non_class
// ignore_for_file: mixin_of_non_class, field_initializer_outside_constructor
// ignore_for_file: final_not_initialized, super_in_invalid_context
// ignore_for_file: concrete_class_with_abstract_member, type_argument_not_matching_bounds
// ignore_for_file: missing_required_argument, undefined_named_parameter
// ignore_for_file: argument_type_not_assignable, invalid_constructor_name
// ignore_for_file: super_formal_parameter_without_associated_named, undefined_annotation
// ignore_for_file: creation_with_non_type, invalid_factory_name_not_a_class
// ignore_for_file: invalid_reference_to_this, expected_class_member
// ignore_for_file: body_might_complete_normally, not_initialized_non_nullable_instance_field
// ignore_for_file: unchecked_use_of_nullable_value, return_of_invalid_type
// ignore_for_file: missing_function_body, extra_positional_arguments
// ignore_for_file: not_enough_positional_arguments, unused_label
// ignore_for_file: unused_element_parameter, non_type_as_type_argument
// ignore_for_file: expected_identifier_but_got_keyword, expected_token
// ignore_for_file: missing_identifier, unexpected_token
// ignore_for_file: duplicate_definition, override_on_non_overriding_member
// ignore_for_file: extends_non_class, no_default_super_constructor
// ignore_for_file: extra_positional_arguments_could_be_named, missing_function_parameters
// ignore_for_file: invalid_annotation, invalid_assignment
// ignore_for_file: expected_executable, named_parameter_outside_group
// ignore_for_file: obsolete_colon_for_default_value, referenced_before_declaration
// ignore_for_file: await_in_wrong_context, non_type_in_catch_clause
// ignore_for_file: could_not_infer, uri_does_not_exist
// ignore_for_file: const_method, redirect_to_non_class
// ignore_for_file: unused_catch_clause, type_test_with_undefined_name
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_class
// ignore_for_file: undefined_super_member, extraneous_modifier
// ignore_for_file: experiment_not_enabled, missing_const_final_var_or_type
// ignore_for_file: undefined_operator, dead_code
// ignore_for_file: invalid_override, not_initialized_non_nullable_variable
// ignore_for_file: list_element_type_not_assignable, assignment_to_final
// ignore_for_file: equal_elements_in_set, prefix_shadowed_by_local_declaration
// ignore_for_file: const_initialized_with_non_constant_value, non_constant_list_element
// ignore_for_file: missing_statement, unnecessary_cast
// ignore_for_file: unnecessary_null_comparison, unnecessary_type_check
// ignore_for_file: invalid_super_formal_parameter_location, assignment_to_type
// ignore_for_file: instance_member_access_from_factory, field_initializer_not_assignable
// ignore_for_file: constant_pattern_with_non_constant_expression, undefined_identifier_await
// ignore_for_file: cast_to_non_type, read_potentially_unassigned_final
// ignore_for_file: mixin_with_non_class_superclass, instantiate_abstract_class
// ignore_for_file: dead_code_on_catch_subtype, unreachable_switch_case
// ignore_for_file: new_with_undefined_constructor, assignment_to_final_local
// ignore_for_file: late_final_local_already_assigned, missing_default_value_for_parameter
// ignore_for_file: non_bool_condition, non_exhaustive_switch_expression
// ignore_for_file: illegal_async_return_type, type_test_with_non_type
// ignore_for_file: invocation_of_non_function_expression, return_of_invalid_type_from_closure
// ignore_for_file: wrong_number_of_type_arguments_constructor, definitely_unassigned_late_local_variable
// ignore_for_file: static_access_to_instance_member, const_with_undefined_constructor
// ignore_for_file: abstract_super_member_reference, equal_keys_in_map
// ignore_for_file: unused_catch_stack, non_constant_default_value
// ignore_for_file: not_a_type
// Test fixture for async rules

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
// Stream Rules
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
// Async/Build Rules
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
// Async Rules (continued)
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
