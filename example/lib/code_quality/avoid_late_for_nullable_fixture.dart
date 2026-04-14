// ignore_for_file: unused_field, unused_local_variable
// Test fixture for avoid_late_for_nullable rule

// =========================================================================
// BAD: Outer type is nullable — late adds crash risk
// =========================================================================

class BadLateNullableFields {
  // expect_lint: avoid_late_for_nullable
  late String? _name;

  // expect_lint: avoid_late_for_nullable
  late List<int>? _items;

  // expect_lint: avoid_late_for_nullable
  late Future<int>? _dataFuture;

  // expect_lint: avoid_late_for_nullable
  late Stream<bool>? _prefStream;

  // expect_lint: avoid_late_for_nullable
  late Map<String, int>? _cache;

  // expect_lint: avoid_late_for_nullable
  late void Function()? _callback;
}

void badLateNullableLocals() {
  // expect_lint: avoid_late_for_nullable
  late int? count;

  // expect_lint: avoid_late_for_nullable
  late String? message;
}

// =========================================================================
// GOOD: Outer type is non-nullable — late is valid
// =========================================================================

class GoodLateNonNullableFields {
  // OK: outer type is non-nullable
  late String _name;

  // OK: outer type is Future (non-nullable), ? is on inner parameter
  late Future<String?> _result;

  // OK: outer type is Map (non-nullable), ? is on inner value type
  late Map<String, List<int>?> _cache;

  // OK: outer type is Stream (non-nullable), ? is inside record parameter
  late Stream<(String?, int)> _stream;

  // OK: outer type is Future (non-nullable), ? is inside record field
  late Future<({List<String>? countries, int count})> _dataFuture;

  // OK: outer type is List (non-nullable)
  late List<int> _items;

  // OK: outer type is function (non-nullable)
  late void Function(String?) _callback;
}

void goodLateNonNullableLocals() {
  // OK: outer type is non-nullable
  late int count;

  // OK: outer type is non-nullable, ? is on inner parameter
  late Future<int?> result;
}
