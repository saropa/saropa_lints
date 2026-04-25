// ignore_for_file: unused_element

/// Fixture for `prefer_compact_declarations` (opinionated opposite).

void badProcess() {
  final a = 1;

  // LINT: unnecessary blank after declaration
  print(a);
}

void goodProcess() {
  final a = 1;
  print(a);
}
