// ignore_for_file: unused_local_variable
// Fixture for prefer_fold_over_reduce: bad/good and false-positive cases.

void bad() {
  final numbers = <int>[1, 2, 3];
  final sum =
      numbers.reduce((a, b) => a + b); // expect_lint: prefer_fold_over_reduce
}

void good() {
  final numbers = <int>[1, 2, 3];
  final sum = numbers.fold(0, (a, b) => a + b);
}
