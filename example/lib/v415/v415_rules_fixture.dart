// ignore_for_file: unused_local_variable, prefer_const_constructors
// ignore_for_file: unused_element, avoid_print, unused_field
// Test fixture for v4.1.5 lint rules (24 new rules)

import '../flutter_mocks.dart';

// =============================================================================
// Dependency Injection Rules
// =============================================================================

// BAD: GetIt in widget
class BadDiWidget extends StatelessWidget {
  const BadDiWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_di_in_widgets
    final service = GetIt.I<UserService>();
    return Text(service.name);
  }
}

// BAD: Concrete type injection
class BadConcreteInjection {
  // expect_lint: prefer_abstraction_injection
  BadConcreteInjection(this._httpClientImpl);
  final HttpClientImpl _httpClientImpl;
}

// GOOD: Abstract type injection
class GoodAbstractInjection {
  GoodAbstractInjection(this._client);
  final ApiClient _client;
}

// =============================================================================
// Accessibility Rules
// =============================================================================

// BAD: Small touch target
class SmallTouchWidget extends StatelessWidget {
  const SmallTouchWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: prefer_large_touch_targets
    return GestureDetector(
      child: Container(width: 30, height: 30), // Too small!
      onTap: () {},
    );
  }
}

// BAD: Short toast duration
void testShortDuration(BuildContext context) {
  // expect_lint: avoid_time_limits
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Quick message'),
      duration: Duration(seconds: 2), // Too short!
    ),
  );
}

// BAD: Drag without button alternative
class DragWithoutButtonWidget extends StatelessWidget {
  const DragWithoutButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: require_drag_alternatives
    return ReorderableListView(
      children: [Container(key: Key('1'))],
      onReorder: (_, __) {},
    );
  }
}

// =============================================================================
// Flutter Widget Rules
// =============================================================================

// BAD: GlobalKey in StatefulWidget
// expect_lint: avoid_global_keys_in_state
class BadGlobalKeyWidget extends StatefulWidget {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>(); // Wrong place!

  @override
  State<BadGlobalKeyWidget> createState() => _BadGlobalKeyWidgetState();
}

class _BadGlobalKeyWidgetState extends State<BadGlobalKeyWidget> {
  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: GlobalKey in State
class GoodGlobalKeyWidget extends StatefulWidget {
  const GoodGlobalKeyWidget({super.key});

  @override
  State<GoodGlobalKeyWidget> createState() => _GoodGlobalKeyWidgetState();
}

class _GoodGlobalKeyWidgetState extends State<GoodGlobalKeyWidget> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>(); // Correct!

  @override
  Widget build(BuildContext context) => Container();
}

// BAD: Static router config
class AppRouter {
  // expect_lint: avoid_static_route_config
  static final GoRouter router = GoRouter(routes: []);
}

// =============================================================================
// State Management Rules
// =============================================================================

// BAD: Using base riverpod in Flutter app
// expect_lint: require_flutter_riverpod_not_riverpod
// import 'package:riverpod/riverpod.dart';  // Should use flutter_riverpod

// BAD: Navigation in Riverpod provider
class BadNavigationNotifier extends StateNotifier<int> {
  BadNavigationNotifier(this._navigatorKey) : super(0);
  final GlobalKey<NavigatorState> _navigatorKey;

  void goToDetails() {
    // expect_lint: avoid_riverpod_navigation
    _navigatorKey.currentState?.pushNamed('/details');
  }
}

// =============================================================================
// Firebase Rules
// =============================================================================

Future<void> testFirebaseWithoutErrorHandling() async {
  // expect_lint: require_firebase_error_handling
  await FirebaseFirestore.instance.collection('users').get();
}

class FirebaseInBuildWidget extends StatelessWidget {
  const FirebaseInBuildWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_firebase_realtime_in_build
    final stream = FirebaseFirestore.instance.collection('users').snapshots();
    return Container();
  }
}

// GOOD: Firebase with error handling
Future<void> testFirebaseWithErrorHandling() async {
  try {
    await FirebaseFirestore.instance.collection('users').get();
  } on FirebaseException catch (e) {
    print('Error: $e');
  }
}

// =============================================================================
// Security Rules
// =============================================================================

Future<void> testSecureStorageWithoutErrorHandling() async {
  final storage = FlutterSecureStorage();
  // expect_lint: require_secure_storage_error_handling
  await storage.read(key: 'token');
}

Future<void> testSecureStorageLargeData() async {
  final storage = FlutterSecureStorage();
  // expect_lint: avoid_secure_storage_large_data
  await storage.write(key: 'data', value: jsonEncode(largeObject));
}

// GOOD: Secure storage with error handling
Future<void> testSecureStorageWithErrorHandling() async {
  final storage = FlutterSecureStorage();
  try {
    await storage.read(key: 'token');
  } catch (e) {
    print('Error: $e');
  }
}

// =============================================================================
// Navigation Rules
// =============================================================================

void testNavigatorContextIssue(GlobalKey<ScaffoldState> scaffoldKey) {
  // expect_lint: avoid_navigator_context_issue
  Navigator.of(scaffoldKey.currentContext!).push(
    MaterialPageRoute(builder: (_) => Container()),
  );
}

Future<void> testUntypedPush(BuildContext context) async {
  // expect_lint: require_pop_result_type
  final result = await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SelectionPage()),
  );
}

void testPushReplacementMisuse(BuildContext context) {
  // expect_lint: avoid_push_replacement_misuse
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => ProductDetailPage()),
  );
}

class NestedNavigatorWithoutPopScope extends StatelessWidget {
  const NestedNavigatorWithoutPopScope({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_nested_navigators_misuse
    return TabBarView(
      children: [
        Navigator(onGenerateRoute: (_) => null),
        Navigator(onGenerateRoute: (_) => null),
      ],
    );
  }
}

void testDeepLinkWithObject(BuildContext context) {
  // expect_lint: require_deep_link_testing
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductPage(),
      settings: RouteSettings(arguments: Product(name: 'Test')),
    ),
  );
}

// =============================================================================
// Internationalization Rules
// =============================================================================

class StringConcatWidget extends StatelessWidget {
  const StringConcatWidget({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_string_concatenation_l10n
    return Text('Hello ' + name + '!');
  }
}

void testIntlWithoutDescription() {
  // expect_lint: prefer_intl_message_description
  Intl.message('Submit'); // Missing desc parameter
}

class HardcodedStringWidget extends StatelessWidget {
  const HardcodedStringWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_hardcoded_locale_strings
    return Text('Welcome back!');
  }
}

// GOOD: Using localization
void testIntlWithDescription() {
  Intl.message('Submit', desc: 'Button to submit the form');
}

// =============================================================================
// Async Rules
// =============================================================================

class NetworkService {
  // expect_lint: require_network_status_check
  Future<void> fetchData() async {
    final response = await http.get(Uri.parse('https://api.example.com'));
  }
}

class SyncOnChangeWidget extends StatelessWidget {
  const SyncOnChangeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_sync_on_every_change
    return TextField(
      onChanged: (value) async {
        await api.saveNote(value); // Syncs every keystroke!
      },
    );
  }
}

class PendingChangesService {
  final List<Object> _pendingChanges = [];

  // expect_lint: require_pending_changes_indicator
  void save(Object change) {
    _pendingChanges.add(change);
    // No notification to UI!
  }
}

// GOOD: With debouncing
class DebouncedSyncWidget extends StatelessWidget {
  const DebouncedSyncWidget({super.key});
  final Debouncer _debouncer = const Debouncer();

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: (value) {
        _debouncer.run(() => api.saveNote(value));
      },
    );
  }
}

// =============================================================================
// Mock Classes
// =============================================================================

class UserService {
  String get name => 'User';
}

class HttpClientImpl {}

abstract class ApiClient {}

class GetIt {
  static final GetIt I = GetIt._();
  GetIt._();
  T call<T>() => throw UnimplementedError();
}

class GoRouter {
  GoRouter({required List<Object> routes});
}

class StateNotifier<T> {
  StateNotifier(this.state);
  T state;
}

class FirebaseFirestore {
  static final FirebaseFirestore instance = FirebaseFirestore._();
  FirebaseFirestore._();
  CollectionReference collection(String path) => CollectionReference();
}

class CollectionReference {
  Future<Object> get() async => Object();
  Stream<Object> snapshots() => Stream.empty();
}

class FirebaseException implements Exception {
  final String message;
  FirebaseException(this.message);
}

class FlutterSecureStorage {
  Future<String?> read({required String key}) async => null;
  Future<void> write({required String key, required String value}) async {}
}

String jsonEncode(Object obj) => '{}';
final Object largeObject = Object();

class SelectionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container();
}

class ProductDetailPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container();
}

class ProductPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container();
}

class Product {
  final String name;
  Product({required this.name});
}

class http {
  static Future<Object> get(Uri uri) async => Object();
}

class api {
  static Future<void> saveNote(String value) async {}
}

class Debouncer {
  const Debouncer();
  void run(void Function() callback) {}
}

class Intl {
  static String message(String text, {String? desc, List<Object>? args}) =>
      text;
}
