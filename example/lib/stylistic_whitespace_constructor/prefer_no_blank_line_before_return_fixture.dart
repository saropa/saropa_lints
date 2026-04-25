// ignore_for_file: unused_element

/// Fixture for `prefer_no_blank_line_before_return`.

int badSum(int a, int b) {
  final s = a + b;

  // LINT: blank line before return adds vertical gap per this rule
  return s;
}

int goodSum(int a, int b) {
  final s = a + b;
  return s;
}
