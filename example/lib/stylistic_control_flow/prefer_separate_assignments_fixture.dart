// ignore_for_file: unused_element
// Fixture for prefer_separate_assignments: prefer separate statements over cascade.

void f() {
  final buf = StringBuffer();
  // LINT: cascade assignment
  buf
    ..write('a')
    ..write('b');
}

void g() {
  final buf = StringBuffer();
  // OK: separate statements
  buf.write('a');
  buf.write('b');
}
