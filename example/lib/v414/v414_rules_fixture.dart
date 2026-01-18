// ignore_for_file: unused_local_variable, prefer_const_constructors
// ignore_for_file: unused_element, avoid_print, unused_field
// Test fixture for v4.1.4 lint rules (25 new rules)

import '../flutter_mocks.dart';

// =============================================================================
// Bloc/Cubit Rules
// =============================================================================

// Mock classes for Bloc testing
class UserRepository {}

class AuthRepository {}

// BAD: Bloc depending on another Bloc
class BadOrderBloc extends Bloc<Object, Object> {
  // expect_lint: avoid_passing_bloc_to_bloc
  BadOrderBloc(this.userBloc) : super(Object());
  final UserBloc userBloc;
}

// GOOD: Bloc with repository injection
class GoodOrderBloc extends Bloc<Object, Object> {
  GoodOrderBloc({required this.repository}) : super(Object());
  final UserRepository repository;
}

// BAD: BuildContext in Bloc
class BadContextBloc extends Bloc<Object, Object> {
  // expect_lint: avoid_passing_build_context_to_blocs
  BadContextBloc(this.context) : super(Object());
  final BuildContext context;
}

// BAD: Bloc creating its own repository
class BadDependencyBloc extends Bloc<Object, Object> {
  BadDependencyBloc() : super(Object()) {
    // expect_lint: require_bloc_repository_injection
    _repository = UserRepository();
  }
  late final UserRepository _repository;
}

// BAD: Cubit returning value
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  // expect_lint: avoid_returning_value_from_cubit_methods
  int increment() {
    emit(state + 1);
    return state;
  }
}

// GOOD: Cubit emitting state
class GoodCounterCubit extends Cubit<int> {
  GoodCounterCubit() : super(0);

  void increment() {
    emit(state + 1);
  }
}

// =============================================================================
// GetX Rules
// =============================================================================

class BadGetxController extends GetxController {
  void showError() {
    // expect_lint: avoid_getx_dialog_snackbar_in_controller
    Get.snackbar('Error', 'Something went wrong');
  }
}

void testGetxLazyPut() {
  // expect_lint: require_getx_lazy_put
  Get.put(BadGetxController());

  // GOOD: Using lazyPut
  Get.lazyPut(() => BadGetxController());
}

// =============================================================================
// Hive/SharedPreferences Rules
// =============================================================================

// BAD: Regular Box for potentially large collection
class MessageService {
  // expect_lint: prefer_hive_lazy_box
  late Box<Object> messagesBox;
}

// GOOD: LazyBox for large collection
class GoodMessageService {
  late LazyBox<Object> messagesBox;
}

// BAD: Binary data in Hive
@HiveType(typeId: 0)
class BadPhoto {
  // expect_lint: avoid_hive_binary_storage
  Uint8List imageBytes = Uint8List(0);
}

// GOOD: Store path instead
@HiveType(typeId: 1)
class GoodPhoto {
  String imagePath = '';
}

void testSharedPrefsRules() async {
  // expect_lint: require_shared_prefs_prefix
  // expect_lint: prefer_shared_prefs_async_api
  final prefs = await SharedPreferences.getInstance();
}

// BAD: SharedPreferences in isolate context
Future<void> isolateEntry(SendPort sendPort) async {
  // expect_lint: avoid_shared_prefs_in_isolate
  final prefs = await SharedPreferences.getInstance();
}

// =============================================================================
// Stream Rules
// =============================================================================

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

// =============================================================================
// Async/Build Rules
// =============================================================================

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
      future: fetchData(),
      builder: (context, snapshot) => Container(),
    );
  }

  Future<String> fetchData() async => 'data';
}

class BadMountedCheckWidget extends StatefulWidget {
  const BadMountedCheckWidget({super.key});

  @override
  State<BadMountedCheckWidget> createState() => _BadMountedCheckWidgetState();
}

class _BadMountedCheckWidgetState extends State<BadMountedCheckWidget> {
  String _data = '';

  Future<void> loadData() async {
    final data = await fetchData();
    // expect_lint: require_mounted_check_after_await
    setState(() => _data = data);
  }

  Future<String> fetchData() async => 'data';

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
    final data = await fetchData();
    if (!mounted) return;
    setState(() => _data = data);
  }

  Future<String> fetchData() async => 'data';

  @override
  Widget build(BuildContext context) => Text(_data);
}

// =============================================================================
// Widget Lifecycle Rules
// =============================================================================

class BadDialogWidget extends StatefulWidget {
  const BadDialogWidget({super.key});

  @override
  State<BadDialogWidget> createState() => _BadDialogWidgetState();
}

class _BadDialogWidgetState extends State<BadDialogWidget> {
  @override
  void initState() {
    super.initState();
    // expect_lint: require_widgets_binding_callback
    showDialog(context: context, builder: (_) => Container());
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Using addPostFrameCallback
class GoodDialogWidget extends StatefulWidget {
  const GoodDialogWidget({super.key});

  @override
  State<GoodDialogWidget> createState() => _GoodDialogWidgetState();
}

class _GoodDialogWidgetState extends State<GoodDialogWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(context: context, builder: (_) => Container());
    });
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =============================================================================
// Navigation Rules
// =============================================================================

void testRouteSettings(BuildContext context) {
  // expect_lint: prefer_route_settings_name
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => Container()),
  );

  // GOOD: With RouteSettings
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Container(),
      settings: const RouteSettings(name: '/details'),
    ),
  );
}

// =============================================================================
// Internationalization Rules
// =============================================================================

class NumberFormatWidget extends StatelessWidget {
  const NumberFormatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final price = 1234.56;
    // expect_lint: prefer_number_format
    return Text(price.toStringAsFixed(2));
  }
}

void testIntlArgs() {
  final name = 'John';
  // expect_lint: provide_correct_intl_args
  Intl.message(
    'Hello {name}, you have {count} messages',
    args: [name], // Missing 'count' argument!
  );
}

// =============================================================================
// Package-specific Rules
// =============================================================================

// BAD: Freezed on logic class
// expect_lint: avoid_freezed_for_logic_classes
@freezed
class BadUserService {}

// GOOD: Freezed on data class
@freezed
class User {}

// =============================================================================
// Disposal Rules
// =============================================================================

// BAD: Disposable fields without dispose method
// expect_lint: dispose_class_fields
class BadService {
  final StreamController<int> _controller = StreamController<int>();
  final Timer _timer = Timer(Duration.zero, () {});
}

// GOOD: With dispose method
class GoodService {
  final StreamController<int> _controller = StreamController<int>();

  void dispose() {
    _controller.close();
  }
}

// =============================================================================
// State Management Rules
// =============================================================================

class AuthService extends ChangeNotifier {}

class UserNotifier extends ChangeNotifier {
  void updateAuth(AuthService auth) {}
}

void testChangeNotifierProxyProvider(BuildContext context) {
  // expect_lint: prefer_change_notifier_proxy_provider
  ChangeNotifierProvider(
    create: (context) {
      final auth = context.read<AuthService>();
      return UserNotifier()..updateAuth(auth);
    },
    child: Container(),
  );

  // GOOD: Using ProxyProvider
  ChangeNotifierProxyProvider<AuthService, UserNotifier>(
    create: (_) => UserNotifier(),
    update: (_, auth, previous) => previous!..updateAuth(auth),
    child: Container(),
  );
}
