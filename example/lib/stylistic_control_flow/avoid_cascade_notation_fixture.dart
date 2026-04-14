// ignore_for_file: unused_local_variable
// Fixture for avoid_cascade_notation: bad/good and false-positive cases.

void bad() {
  final list = <int>[]
    ..add(1)
    ..add(2); // expect_lint: avoid_cascade_notation
}

void good() {
  final list = <int>[];
  list.add(1);
  list.add(2);
}
