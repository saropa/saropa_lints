// ignore_for_file: unused_local_variable, unused_element
// Test fixture for: prefer_iterable_cast
// Source: lib/src/rules/config/flutter_sdk_migration_rules.dart

void preferIterableCastBad() {
  final source = <Object>[1, 2, 3];

  // expect_lint: prefer_iterable_cast
  final a = Iterable.castFrom<Object, int>(source);
  // expect_lint: prefer_iterable_cast
  final b = List.castFrom<Object, int>(source);
  // expect_lint: prefer_iterable_cast
  final c = Set.castFrom<Object, int>(source.toSet());
  // expect_lint: prefer_iterable_cast
  final d = Map.castFrom<Object, Object, String, int>(<Object, Object>{});
}

void preferIterableCastGood() {
  final source = <Object>[1, 2, 3];
  final a = source.cast<int>();
  final b = List<int>.from(source);
  final c = Set<int>.from(source);
  final d = Map<String, int>.from(<Object, Object>{});
  final user = _UserCastable<int>();
  user.castFrom<int>(source);
}

class _UserCastable<T> {
  void castFrom<U>(Iterable<Object?> _) {}
}
