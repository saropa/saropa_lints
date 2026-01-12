# ROADMAP_NEXT: 42 Priority Rules for Implementation

This document details **42 starred rules** from ROADMAP.md - the easiest-to-implement rules with low false-positive risk. These rules match exact API/method names, check specific named parameters, or detect missing required parameters.

> **Note**: 3 rules were moved to "Deferred - Complex Rules" in ROADMAP.md as they require cross-file analysis.

## Implementation Summary

| Priority | Count | Focus Area |
|----------|-------|------------|
| Phase 1 - Critical | 2 | Essential/WARNING rules that prevent crashes |
| Phase 2 - Core Quality | 5 | Code quality and async safety |
| Phase 3 - Testing | 6 | Test best practices |
| Phase 4 - State Management | 9 | Provider, Riverpod, Bloc, GetX |
| Phase 5 - Package-Specific | 20 | Dio, GoRouter, SQLite, Freezed, etc. |

---

## Phase 1: Critical Rules (2 rules)

These are Essential-tier rules with WARNING severity that prevent crashes and data loss.

### 1.1 `require_mounted_check_after_await`

| Property | Value |
|----------|-------|
| **Tier** | Essential |
| **Severity** | WARNING |
| **Category** | Async/Lifecycle |
| **File** | `async_rules.dart` or `context_rules.dart` |

**Description**: Check `mounted` after `await` in StatefulWidget before calling `setState`. Widget may be disposed during async operation.

**Detection Pattern**:
```dart
// BAD
Future<void> loadData() async {
  final data = await fetchData();
  setState(() => _data = data); // Widget may be disposed!
}

// GOOD
Future<void> loadData() async {
  final data = await fetchData();
  if (!mounted) return;
  setState(() => _data = data);
}
```

**Implementation Approach**:
1. Find `await` expressions in methods of `State<T>` classes
2. Check for `setState` calls after the await
3. Verify there's a `mounted` check between await and setState
4. Use existing `async_context_utils.dart` for shared logic

**Complexity**: Low-Medium (single-file, AST pattern)

**Note**: Similar to existing `avoid_context_across_async` - may share utilities

**Quick Fix**: Insert `if (!mounted) return;` after await

---

### 1.2 `avoid_test_sleep`

| Property | Value |
|----------|-------|
| **Tier** | Essential |
| **Severity** | WARNING |
| **Category** | Testing |
| **File** | `test_rules.dart` |

**Description**: Don't use `sleep()` in tests. Use `pump()`, `pumpAndSettle()`, or `pumpWidget()` for widget tests.

**Detection Pattern**:
```dart
// BAD - in test file
testWidgets('my test', (tester) async {
  sleep(Duration(seconds: 1)); // Blocks test runner
});

// GOOD
testWidgets('my test', (tester) async {
  await tester.pump(Duration(seconds: 1));
});
```

**Implementation Approach**:
1. Detect files in `test/` directory or with `_test.dart` suffix
2. Find calls to `sleep(Duration...)` or `Future.delayed` without await
3. Report with suggestion to use `pump()` instead

**Complexity**: Low (exact API match)

**Quick Fix**: Replace `sleep(duration)` with `await tester.pump(duration)`

---

## Phase 2: Core Code Quality (5 rules)

Simple AST patterns that improve code quality.

### 2.1 `no_boolean_literal_compare`

| Property | Value |
|----------|-------|
| **Tier** | Recommended |
| **Severity** | INFO |
| **Category** | Boolean/Conditional |
| **File** | `code_quality_rules.dart` |

**Description**: Avoid comparing boolean expressions to boolean literals.

**Detection Pattern**:
```dart
// BAD
if (isEnabled == true) { }
if (isEnabled == false) { }
if (true == isEnabled) { }

// GOOD
if (isEnabled) { }
if (!isEnabled) { }
```

**Implementation Approach**:
1. Find `BinaryExpression` with `==` or `!=` operator
2. Check if either operand is `BooleanLiteral` (`true` or `false`)
3. Report if comparing boolean to boolean literal

**Complexity**: Very Low (simple AST pattern)

**Quick Fix**:
- `x == true` -> `x`
- `x == false` -> `!x`
- `x != true` -> `!x`
- `x != false` -> `x`

---

### 2.2 `prefer_returning_conditional_expressions`

| Property | Value |
|----------|-------|
| **Tier** | Recommended |
| **Severity** | INFO |
| **Category** | Boolean/Conditional |
| **File** | `code_quality_rules.dart` |

**Description**: Return conditional expressions directly instead of if/else blocks.

**Detection Pattern**:
```dart
// BAD
if (condition) {
  return true;
} else {
  return false;
}

// GOOD
return condition;

// BAD
if (condition) {
  return valueA;
} else {
  return valueB;
}

// GOOD
return condition ? valueA : valueB;
```

**Implementation Approach**:
1. Find `IfStatement` with both `then` and `else` branches
2. Check if both branches contain only a single `ReturnStatement`
3. Report with suggestion to use ternary or direct return

**Complexity**: Low (AST pattern)

**Quick Fix**: Transform to ternary expression

---

### 2.3 `avoid_not_encodable_in_to_json`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | WARNING |
| **Category** | JSON/Serialization |
| **File** | `json_datetime_rules.dart` |

**Description**: Detect `toJson` methods that return non-JSON-encodable types.

**Detection Pattern**:
```dart
// BAD
Map<String, dynamic> toJson() {
  return {
    'date': DateTime.now(), // DateTime not JSON-encodable!
    'callback': myFunction, // Function not JSON-encodable!
    'widget': MyWidget(),   // Widget not JSON-encodable!
  };
}

// GOOD
Map<String, dynamic> toJson() {
  return {
    'date': DateTime.now().toIso8601String(),
  };
}
```

**Implementation Approach**:
1. Find methods named `toJson` returning `Map<String, dynamic>`
2. Analyze `MapLiteralEntry` values for non-encodable types:
   - `DateTime` (suggest `.toIso8601String()`)
   - `Function`
   - Custom classes without `toJson`
   - `Widget`, `BuildContext`

**Complexity**: Medium (type analysis)

**Quick Fix**: For DateTime, suggest `.toIso8601String()`

---

### 2.4 `prefer_constructor_injection`

| Property | Value |
|----------|-------|
| **Tier** | Essential |
| **Severity** | INFO |
| **Category** | Dependency Injection |
| **File** | `dependency_injection_rules.dart` |

**Description**: Inject dependencies via constructor, not service locator in constructor body.

**Detection Pattern**:
```dart
// BAD
class MyService {
  late final ApiClient _api;

  MyService() {
    _api = GetIt.I<ApiClient>(); // Service locator in body
  }
}

// GOOD
class MyService {
  final ApiClient _api;

  MyService(this._api); // Constructor injection
}
```

**Implementation Approach**:
1. Find constructor bodies
2. Look for `GetIt.I<T>()`, `GetIt.instance<T>()`, `locator<T>()` calls
3. Report with suggestion to use constructor parameter

**Complexity**: Low (exact API match)

**Quick Fix**: Add constructor parameter, remove GetIt call

---

### 2.5 `prefer_future_wait`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | Async |
| **File** | `async_rules.dart` |

**Description**: Use `Future.wait` for parallel execution of independent futures.

**Detection Pattern**:
```dart
// BAD - Sequential (slow)
final a = await fetchA();
final b = await fetchB();
final c = await fetchC();

// GOOD - Parallel (fast)
final results = await Future.wait([fetchA(), fetchB(), fetchC()]);
// Or with destructuring:
final (a, b, c) = await (fetchA(), fetchB(), fetchC()).wait;
```

**Implementation Approach**:
1. Find consecutive `await` expressions in same block
2. Check if the awaited futures are independent (don't use each other's results)
3. Suggest `Future.wait` for 2+ independent sequential awaits

**Complexity**: Medium (data flow analysis)

**Quick Fix**: Wrap in `Future.wait([...])`

---

## Phase 3: Testing Rules (6 rules)

### 3.1 `prefer_test_find_by_key`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | Testing |
| **File** | `test_rules.dart` |

**Description**: Use Keys for reliable widget finding instead of `find.text` for dynamic text.

**Detection Pattern**:
```dart
// BAD - Fragile, breaks if text changes
await tester.tap(find.text('Submit'));
await tester.tap(find.text(localizedString));

// GOOD - Stable
await tester.tap(find.byKey(Key('submit_button')));
```

**Implementation Approach**:
1. Find `find.text()` calls in test files
2. Check if the text is a variable or localized string (not literal)
3. Suggest using `find.byKey()` instead

**Complexity**: Low (API pattern)

---

### 3.2 `prefer_setup_teardown`

| Property | Value |
|----------|-------|
| **Tier** | Recommended |
| **Severity** | INFO |
| **Category** | Testing |
| **File** | `test_rules.dart` |

**Description**: Use `setUp`/`tearDown` for common operations instead of repeating in each test.

**Detection Pattern**:
```dart
// BAD - Repeated setup
test('test 1', () {
  final repo = MockRepository();
  final bloc = MyBloc(repo);
  // ...
});
test('test 2', () {
  final repo = MockRepository(); // Same setup!
  final bloc = MyBloc(repo);
  // ...
});

// GOOD
late MockRepository repo;
late MyBloc bloc;

setUp(() {
  repo = MockRepository();
  bloc = MyBloc(repo);
});
```

**Implementation Approach**:
1. Find test groups with multiple `test()` or `testWidgets()` calls
2. Detect repeated variable declarations at start of each test
3. Suggest moving to `setUp()`

**Complexity**: Medium (pattern detection across tests)

---

### 3.3 `require_test_description`

| Property | Value |
|----------|-------|
| **Tier** | Recommended |
| **Severity** | INFO |
| **Category** | Testing |
| **File** | `test_rules.dart` |

**Description**: Test names should describe behavior, not be vague.

**Detection Pattern**:
```dart
// BAD - Vague names
test('test 1', () { });
test('it works', () { });
test('MyBloc', () { });

// GOOD - Descriptive
test('should emit Loading then Success when fetch succeeds', () { });
test('returns null when user not found', () { });
```

**Implementation Approach**:
1. Find `test()` and `testWidgets()` calls
2. Check first string argument (test name)
3. Flag if:
   - Too short (< 10 chars)
   - Matches vague patterns: `test \d+`, `it works`, just a class name
   - No verb describing behavior

**Complexity**: Low (string pattern)

---

### 3.4 `prefer_bloc_test_package`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | Testing |
| **File** | `test_rules.dart` |

**Description**: Use `bloc_test` package for Bloc testing instead of manual setup.

**Detection Pattern**:
```dart
// BAD - Manual Bloc testing
test('MyBloc emits states', () async {
  final bloc = MyBloc();
  bloc.add(MyEvent());
  await expectLater(
    bloc.stream,
    emitsInOrder([MyState()]),
  );
});

// GOOD - Using bloc_test
blocTest<MyBloc, MyState>(
  'emits [Loading, Success] when MyEvent added',
  build: () => MyBloc(),
  act: (bloc) => bloc.add(MyEvent()),
  expect: () => [Loading(), Success()],
);
```

**Implementation Approach**:
1. Detect Bloc class under test (instantiation of `*Bloc` or `*Cubit`)
2. Check if using `bloc_test` package's `blocTest<>()` function
3. If manual `bloc.stream` + `expectLater` pattern, suggest `blocTest`

**Complexity**: Low-Medium (pattern detection)

---

### 3.5 `prefer_mock_verify`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | Testing |
| **File** | `test_rules.dart` |

**Description**: Verify mock interactions to ensure expected methods were called.

**Detection Pattern**:
```dart
// BAD - No verification
test('creates user', () async {
  final mockRepo = MockUserRepository();
  when(mockRepo.create(any)).thenAnswer((_) async => User());

  await useCase.execute(userData);
  // Missing: verify(mockRepo.create(any)).called(1);
});

// GOOD
test('creates user', () async {
  final mockRepo = MockUserRepository();
  when(mockRepo.create(any)).thenAnswer((_) async => User());

  await useCase.execute(userData);
  verify(mockRepo.create(any)).called(1);
});
```

**Implementation Approach**:
1. Find `when()` calls setting up mocks in test
2. Check if corresponding `verify()` or `verifyNever()` exists
3. Report mocks without verification

**Complexity**: Medium (tracking mock setup to verification)

---

### 3.6 `require_error_logging`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | Error Handling |
| **File** | `error_handling_rules.dart` |

**Description**: Caught errors should be logged for debugging and monitoring.

**Detection Pattern**:
```dart
// BAD - Silent catch
try {
  await riskyOperation();
} catch (e) {
  // Error swallowed silently!
}

// GOOD
try {
  await riskyOperation();
} catch (e, stackTrace) {
  logger.error('Operation failed', error: e, stackTrace: stackTrace);
  // or: debugPrint('Error: $e');
}
```

**Implementation Approach**:
1. Find `catch` clauses
2. Check if body contains logging call:
   - `print()`, `debugPrint()`, `log()`, `logger.*`
   - `FirebaseCrashlytics.instance.recordError()`
   - `Sentry.captureException()`
3. Report empty or logging-free catch blocks

**Complexity**: Low (AST pattern)

**Quick Fix**: Add `debugPrint('Error: $e, $stackTrace');`

---

## Phase 4: State Management Rules (9 rules)

### 4.1 Provider Rules (2 rules)

#### `prefer_change_notifier_proxy_provider`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | Provider |

**Description**: Providers depending on others should use `ProxyProvider` instead of manual dependency passing.

**Detection Pattern**:
```dart
// BAD
ChangeNotifierProvider(
  create: (context) => MyNotifier(
    Provider.of<OtherNotifier>(context, listen: false), // Manual!
  ),
)

// GOOD
ChangeNotifierProxyProvider<OtherNotifier, MyNotifier>(
  create: (_) => MyNotifier(),
  update: (_, other, my) => my!..updateWith(other),
)
```

---

#### `prefer_selector_widget`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | Provider |

**Description**: Use `Selector` to limit rebuilds to specific fields instead of `Consumer` rebuilding on any change.

**Detection Pattern**:
```dart
// BAD - Rebuilds on ANY change
Consumer<UserModel>(
  builder: (_, user, __) => Text(user.name), // Only uses name!
)

// GOOD - Only rebuilds when name changes
Selector<UserModel, String>(
  selector: (_, user) => user.name,
  builder: (_, name, __) => Text(name),
)
```

---

### 4.2 Riverpod Rules (2 rules)

#### `prefer_riverpod_auto_dispose`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | Riverpod |

**Description**: Providers should auto-dispose when unused to free memory.

**Detection Pattern**:
```dart
// BAD - Lives forever
final myProvider = StateProvider<int>((ref) => 0);

// GOOD - Auto-disposes when no longer watched
final myProvider = StateProvider.autoDispose<int>((ref) => 0);
```

---

#### `prefer_riverpod_family_for_params`

| Property | Value |
|----------|-------|
| **Tier** | Recommended |
| **Severity** | INFO |
| **Category** | Riverpod |

**Description**: Providers with parameters should use `.family` modifier.

**Detection Pattern**:
```dart
// BAD - Passing params through state
final userProvider = StateProvider<User?>((ref) => null);
// Then somewhere: ref.read(userProvider.notifier).state = fetchUser(userId);

// GOOD
final userProvider = FutureProvider.family<User, String>((ref, userId) {
  return fetchUser(userId);
});
// Usage: ref.watch(userProvider(userId));
```

---

### 4.3 Bloc Rules (3 rules)

#### `require_bloc_event_sealed`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | Bloc |

**Description**: Bloc events should be sealed classes for exhaustive pattern matching.

**Detection Pattern**:
```dart
// BAD - Not exhaustive
abstract class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}

// GOOD - Exhaustive
sealed class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}
```

---

#### `require_bloc_repository_injection`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | Bloc |

**Description**: Blocs should receive repositories via constructor, not create them.

**Detection Pattern**:
```dart
// BAD
class MyBloc extends Bloc<MyEvent, MyState> {
  MyBloc() : super(Initial()) {
    _repository = UserRepository(); // Creating dependency!
  }
  late final UserRepository _repository;
}

// GOOD
class MyBloc extends Bloc<MyEvent, MyState> {
  MyBloc(this._repository) : super(Initial());
  final UserRepository _repository;
}
```

---

#### `prefer_bloc_transform_events`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | Bloc |

**Description**: Use event transformer for debouncing/throttling instead of manual implementation.

**Detection Pattern**:
```dart
// BAD - Manual debounce
on<SearchEvent>((event, emit) async {
  await Future.delayed(Duration(milliseconds: 300)); // Manual debounce
  // ...
});

// GOOD - Using transformer
on<SearchEvent>(
  _onSearch,
  transformer: debounce(Duration(milliseconds: 300)),
);
```

---

### 4.4 GetX Rules (2 rules)

#### `avoid_getx_global_navigation`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | WARNING |
| **Category** | GetX |

**Description**: `Get.to()` uses global context, hurting testability.

**Detection Pattern**:
```dart
// BAD
Get.to(NextPage());
Get.off(HomePage());
Get.toNamed('/details');

// BETTER - Inject navigator or use GoRouter
Navigator.of(context).push(...);
```

---

#### `require_getx_binding_routes`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |
| **Category** | GetX |

**Description**: GetX routes should use Bindings for dependency injection.

**Detection Pattern**:
```dart
// BAD
GetPage(
  name: '/home',
  page: () => HomePage(),
  // Missing binding!
)

// GOOD
GetPage(
  name: '/home',
  page: () => HomePage(),
  binding: HomeBinding(),
)
```

---

## Phase 5: Package-Specific Rules (18 rules)

### 5.1 Dio HTTP Rules (3 rules)

#### `require_dio_response_type`

| Property | Value |
|----------|-------|
| **Tier** | Recommended |
| **Severity** | INFO |

**Description**: Explicitly set `responseType` when processing binary data.

```dart
// BAD
final response = await dio.get(url); // responseType defaults to json

// GOOD
final response = await dio.get(
  url,
  options: Options(responseType: ResponseType.bytes),
);
```

---

#### `require_dio_retry_interceptor`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Network failures should have retry logic.

```dart
// BAD
final dio = Dio();

// GOOD
final dio = Dio()
  ..interceptors.add(RetryInterceptor(
    dio: dio,
    retries: 3,
    retryDelays: [1.seconds, 2.seconds, 3.seconds],
  ));
```

---

#### `prefer_dio_transformer`

| Property | Value |
|----------|-------|
| **Tier** | Comprehensive |
| **Severity** | INFO |

**Description**: Large JSON parsing should use custom transformer with isolates.

```dart
// BAD - Blocks main thread
final response = await dio.get('/large-data');
final data = response.data; // Parsing on main thread

// GOOD
dio.transformer = BackgroundTransformer();
```

---

### 5.2 GoRouter Rules (3 rules)

#### `prefer_shell_route_shared_layout`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Use `ShellRoute` for shared AppBar/BottomNav instead of duplicating Scaffold.

---

#### `require_stateful_shell_route_tabs`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Tab navigation should use `StatefulShellRoute` to preserve state across tabs.

---

#### `require_go_router_fallback_route`

| Property | Value |
|----------|-------|
| **Tier** | Recommended |
| **Severity** | INFO |

**Description**: Router should have catch-all or error route for unknown paths.

```dart
// BAD
GoRouter(routes: [
  GoRoute(path: '/', builder: ...),
  GoRoute(path: '/details', builder: ...),
  // No fallback!
]);

// GOOD
GoRouter(
  errorBuilder: (context, state) => ErrorPage(),
  routes: [...],
);
```

---

### 5.3 SQLite Rules (2 rules)

#### `prefer_sqflite_singleton`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Use singleton database instance instead of multiple `openDatabase` calls.

```dart
// BAD
Future<void> saveUser(User user) async {
  final db = await openDatabase('app.db'); // Opens new connection!
  await db.insert('users', user.toMap());
}

// GOOD
class DatabaseService {
  static Database? _db;
  static Future<Database> get database async {
    return _db ??= await openDatabase('app.db');
  }
}
```

---

#### `prefer_sqflite_column_constants`

| Property | Value |
|----------|-------|
| **Tier** | Recommended |
| **Severity** | INFO |

**Description**: Use constants for column names to avoid typos.

```dart
// BAD
await db.query('users', columns: ['id', 'name', 'emial']); // Typo!

// GOOD
class UserTable {
  static const table = 'users';
  static const colId = 'id';
  static const colName = 'name';
  static const colEmail = 'email';
}
await db.query(UserTable.table, columns: [UserTable.colId, ...]);
```

---

### 5.4 Freezed Rules (2 rules)

#### `require_freezed_json_converter`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Custom types in Freezed classes need `JsonConverter`.

```dart
// BAD - DateTime not handled
@freezed
class User with _$User {
  factory User({
    required DateTime createdAt, // Needs converter!
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

// GOOD
@freezed
class User with _$User {
  @JsonSerializable(converters: [DateTimeConverter()])
  factory User({
    required DateTime createdAt,
  }) = _User;
}
```

---

#### `require_freezed_lint_package`

| Property | Value |
|----------|-------|
| **Tier** | Recommended |
| **Severity** | INFO |

**Description**: Install `freezed_lint` for official linting of Freezed classes.

---

### 5.5 Geolocation Rules (2 rules)

#### `prefer_geolocator_accuracy_appropriate`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Use appropriate accuracy level - high accuracy drains battery.

```dart
// BAD - High accuracy for city-level feature
await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high, // Overkill!
);

// GOOD
await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.low, // City-level is fine
);
```

---

#### `prefer_geolocator_last_known`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Use `lastKnownPosition` for non-critical needs to save battery.

```dart
// Consider using when fresh location isn't critical
final position = await Geolocator.getLastKnownPosition();
```

---

### 5.6 Other Package Rules (6 rules)

#### `prefer_image_picker_multi_selection`

| Property | Value |
|----------|-------|
| **Tier** | Recommended |
| **Severity** | INFO |

**Description**: Use `pickMultiImage` instead of loop calling `pickImage`.

---

#### `require_notification_action_handling`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Notification actions need handlers.

---

#### `require_di_scope_awareness`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Understand singleton vs factory vs lazySingleton scopes in GetIt.

---

#### `require_finally_cleanup`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Use `finally` for guaranteed cleanup, not just in catch.

```dart
// BAD
try {
  file = await File(path).open();
  await processFile(file);
} catch (e) {
  await file?.close(); // May not run if different exception!
}

// GOOD
try {
  file = await File(path).open();
  await processFile(file);
} finally {
  await file?.close(); // Always runs
}
```

---

### 5.7 Equatable/Collections Rules (3 rules)

#### `require_deep_equality_collections`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Collection fields in Equatable need `DeepCollectionEquality`.

```dart
// BAD - List equality fails
class MyState extends Equatable {
  final List<Item> items;
  @override
  List<Object?> get props => [items]; // Compares by reference!
}

// GOOD
class MyState extends Equatable {
  final List<Item> items;
  @override
  List<Object?> get props => [DeepCollectionEquality().hash(items)];
}
```

---

#### `avoid_equatable_datetime`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | WARNING |

**Description**: DateTime equality is problematic due to microsecond precision.

```dart
// BAD
class Event extends Equatable {
  final DateTime timestamp; // Microsecond differences break equality!
  @override
  List<Object?> get props => [timestamp];
}

// GOOD - Compare truncated or formatted
@override
List<Object?> get props => [timestamp.millisecondsSinceEpoch];
```

---

#### `prefer_unmodifiable_collections`

| Property | Value |
|----------|-------|
| **Tier** | Professional |
| **Severity** | INFO |

**Description**: Make collection fields unmodifiable to prevent mutation.

```dart
// BAD
class State {
  final List<Item> items;
  State(this.items); // Can be mutated externally!
}

// GOOD
class State {
  final List<Item> items;
  State(List<Item> items) : items = List.unmodifiable(items);
}
```

---

### 5.8 Hive Rules (1 rule)

#### `prefer_hive_value_listenable`

| Property | Value |
|----------|-------|
| **Tier** | Recommended |
| **Severity** | INFO |

**Description**: Use `box.listenable()` with `ValueListenableBuilder` for reactive UI.

```dart
// BAD - Manual setState
void _saveItem(Item item) async {
  await box.put(item.id, item);
  setState(() {}); // Manual!
}

// GOOD - Reactive
ValueListenableBuilder(
  valueListenable: box.listenable(),
  builder: (context, Box<Item> box, _) {
    return ListView(children: box.values.map(...).toList());
  },
)
```

---

## Implementation Checklist

### Quick Wins (Start Here)

- [ ] `no_boolean_literal_compare` - Very simple AST
- [ ] `avoid_test_sleep` - Exact API match
- [ ] `prefer_returning_conditional_expressions` - Simple AST
- [ ] `require_test_description` - String pattern
- [ ] `require_error_logging` - Pattern in catch blocks

### Medium Effort

- [ ] `require_mounted_check_after_await` - Extends existing utilities
- [ ] `avoid_not_encodable_in_to_json` - Type checking
- [ ] `prefer_future_wait` - Sequential await detection
- [ ] `prefer_constructor_injection` - GetIt pattern
- [ ] Testing rules (6 total)

---

## File Organization

Rules should be added to existing files based on category:

| Rule Category | Target File |
|--------------|-------------|
| Boolean/Conditional | `code_quality_rules.dart` |
| Testing | `test_rules.dart` |
| Async/Lifecycle | `async_rules.dart` |
| JSON | `json_datetime_rules.dart` |
| State Management | `state_management_rules.dart` |
| Riverpod | `riverpod_rules.dart` |
| GetX | `getx_rules.dart` |
| DI | `dependency_injection_rules.dart` |
| Error Handling | `error_handling_rules.dart` |
| Architecture | `architecture_rules.dart` |
| Equatable | `equatable_rules.dart` |
| Hive | `hive_rules.dart` |
| Navigation | `navigation_rules.dart` |

---

## References

- [ROADMAP.md](ROADMAP.md) - Full rule specifications
- [CONTRIBUTING.md](CONTRIBUTING.md) - Implementation guidelines
- [CHANGELOG.md](CHANGELOG.md) - Implemented rules reference
