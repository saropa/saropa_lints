// ignore_for_file: unused_local_variable

/// Fixture for `prefer_if_null_over_ternary`.

void badExamples(String? value) {
  // LINT: null-check ternary → use ??
  final a = value != null ? value : 'default';
  // LINT: inverted null ternary → use ??
  final b = value == null ? 'default' : value;
}

void goodExamples(String? value) {
  final a = value ?? 'default';
}
