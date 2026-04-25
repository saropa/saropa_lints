// ignore_for_file: unused_element

/// Fixture for `prefer_blank_line_after_declarations`.

void badProcess() {
  final a = 1;
  final b = 2;
  // LINT: declarations run straight into logic — insert blank line
  print(a + b);
}

void goodProcess() {
  final a = 1;
  final b = 2;

  print(a + b);
}
