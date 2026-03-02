// ignore_for_file: unused_element
// Fixture for prefer_constructor_over_literals: prefer List.empty(), Map(), Set.empty().

// LINT: empty list literal
final a = <int>[];

// LINT: empty map literal
final b = <String, int>{};

// LINT: empty set literal
final c = <int>{};

// OK
final d = List<int>.empty();
final e = Map<String, int>();
final f = Set<int>.empty();
