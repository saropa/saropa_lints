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

// BAD: SYNCHRONOUS function declared to return a NON-NULLABLE Future — awaiting
// the returned null is a runtime null error. Should trigger.
Future<String> badSyncNonNullable() {
  return null;
}

// GOOD: SYNCHRONOUS function declared to return a NULLABLE Future (`Future<T>?`).
// Null is type-correct; the caller must null-check before awaiting (e.g.
// FutureBuilder.future accepts Future<T>?). Should NOT trigger.
Future<String>? goodSyncNullableFuture() {
  return null;
}

// GOOD: nested nullable Future, conditional null return. Should NOT trigger.
Future<List<int>?>? goodSyncNullableNested(bool b) {
  if (b) {
    return null;
  }
  return Future<List<int>?>.value(<int>[]);
}
