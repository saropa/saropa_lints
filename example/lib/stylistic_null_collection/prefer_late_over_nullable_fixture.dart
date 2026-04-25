// ignore_for_file: unused_element, unused_field

/// Fixture for `prefer_late_over_nullable` (heuristic on nullable fields).

class BadExample {
  // LINT: nullable uninitialized field — rule suggests late when always assigned before use
  String? lazyName;
}

class GoodExample {
  late String lazyName;
}
