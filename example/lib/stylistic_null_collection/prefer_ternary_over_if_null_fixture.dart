// ignore_for_file: unused_local_variable

/// Fixture for `prefer_ternary_over_if_null` (opinionated opposite of ??).

void badExamples(String? value) {
  // LINT: ?? hides both branches for teams preferring explicit ternary
  final a = value ?? 'default';
}

void goodExamples(String? value) {
  final a = value != null ? value : 'default';
}
