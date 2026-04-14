// ignore_for_file: unused_element
// Fixture for avoid_returning_null_for_future.
// Rule flags return null where Future<T> is expected (e.g. async returning null).

// BAD: async function returning null — should trigger
Future<String?> badAsyncReturnNull() async {
  return null;
}

// GOOD: return a value or use Future.value(null) with explicit type
Future<String?> goodAsyncNullable() async {
  return null;
}
