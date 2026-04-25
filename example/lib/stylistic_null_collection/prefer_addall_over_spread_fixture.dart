// ignore_for_file: unused_local_variable

/// Fixture for `prefer_addall_over_spread` (opinionated opposite of spread merge).

void badExamples(List<int> a, List<int> b) {
  // LINT: spread merge allocates a new list each time
  final combined = [...a, ...b];
}

void goodExamples(List<int> a, List<int> b) {
  final combined = a.toList()..addAll(b);
}
