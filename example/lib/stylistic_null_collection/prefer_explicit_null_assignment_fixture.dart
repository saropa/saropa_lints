// ignore_for_file: unused_local_variable

/// Fixture for `prefer_explicit_null_assignment` (opinionated opposite of ??=).

void badExamples() {
  String? name;
  // LINT: ??= hides explicit null branch for teams that prefer if-null-assign
  name ??= 'default';
}

void goodExamples() {
  String? name;
  if (name == null) {
    name = 'default';
  }
}
