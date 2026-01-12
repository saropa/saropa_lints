// ignore_for_file: unused_local_variable, unused_element
// Test fixture for code quality rules added in v2.5.0

// =========================================================================
// no_boolean_literal_compare
// =========================================================================
// Warns when comparing boolean expressions to boolean literals.

void badBooleanComparisons(bool isEnabled, bool? maybeEnabled) {
  // expect_lint: no_boolean_literal_compare
  if (isEnabled == true) {}

  // expect_lint: no_boolean_literal_compare
  if (isEnabled == false) {}

  // expect_lint: no_boolean_literal_compare
  if (true == isEnabled) {}

  // expect_lint: no_boolean_literal_compare
  if (isEnabled != false) {}

  // OK - nullable bool needs explicit comparison
  if (maybeEnabled == true) {} // This is valid for bool?
}

void goodBooleanExpressions(bool isEnabled) {
  if (isEnabled) {} // Direct use
  if (!isEnabled) {} // Negation
}

// =========================================================================
// prefer_future_wait
// =========================================================================
// Warns when sequential awaits could use Future.wait.

Future<void> badSequentialAwaits() async {
  // expect_lint: prefer_future_wait
  final a = await fetchA();
  final b = await fetchB();
  final c = await fetchC();
  print('$a $b $c');
}

Future<void> goodParallelAwaits() async {
  final results = await Future.wait([fetchA(), fetchB(), fetchC()]);
  print(results);
}

Future<void> okDependentAwaits() async {
  // OK - b depends on a
  final a = await fetchA();
  final b = await fetchWithArg(a);
  print('$a $b');
}

// =========================================================================
// prefer_constructor_injection
// =========================================================================
// Warns when setter/method injection is used instead of constructor.

class BadServiceLocatorInjection {
  // expect_lint: prefer_constructor_injection
  late final ApiService _api; // Late field for dependency

  // expect_lint: prefer_constructor_injection
  set api(ApiService api) => _api = api; // Setter injection

  // expect_lint: prefer_constructor_injection
  void configure(UserRepository repo) {
    // Method injection
  }
}

class GoodConstructorInjection {
  const GoodConstructorInjection(this._api, this._repo);

  final ApiService _api;
  final UserRepository _repo;
}

// =========================================================================
// avoid_not_encodable_in_to_json
// =========================================================================
// Warns when toJson returns non-JSON-encodable types.

class BadJsonModel {
  final DateTime createdAt;
  final void Function() callback;

  BadJsonModel(this.createdAt, this.callback);

  Map<String, dynamic> toJson() {
    return {
      // expect_lint: avoid_not_encodable_in_to_json
      'date': DateTime.now(), // DateTime not encodable!
      // expect_lint: avoid_not_encodable_in_to_json
      'callback': callback, // Function not encodable!
    };
  }
}

class GoodJsonModel {
  final DateTime createdAt;
  final String userId;

  GoodJsonModel(this.createdAt, this.userId);

  Map<String, dynamic> toJson() {
    return {
      'date': createdAt.toIso8601String(), // Converted to string
      'userId': userId, // Primitive type
    };
  }
}

// =========================================================================
// require_error_logging
// =========================================================================
// Warns when catch blocks don't log errors.

void badSilentCatch() {
  try {
    riskyOperation();
  } catch (e) {
    // expect_lint: require_error_logging
    // Error swallowed silently!
  }
}

void goodErrorLogging() {
  try {
    riskyOperation();
  } catch (e, stackTrace) {
    debugPrint('Error: $e'); // Logged
    // Or: logger.error('Failed', error: e, stackTrace: stackTrace);
  }
}

// =========================================================================
// Mock classes and functions
// =========================================================================

class ApiService {}
class UserRepository {}

Future<String> fetchA() async => 'a';
Future<String> fetchB() async => 'b';
Future<String> fetchC() async => 'c';
Future<String> fetchWithArg(String arg) async => 'result: $arg';

void riskyOperation() {}
void debugPrint(String message) {}
