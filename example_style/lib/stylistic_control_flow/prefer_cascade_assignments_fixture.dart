// ignore_for_file: unused_element
// Fixture for prefer_cascade_assignments: consecutive calls on same target.

void f() {
  final list = <int>[];
  // LINT: consecutive method calls on same target
  list.add(1);
  list.add(2);
}

void g() {
  final list = <int>[];
  // OK: cascade
  list
    ..add(1)
    ..add(2);
}

// OK: different method names, only 2 calls (independent actions)
void h() {
  final list = <int>[];
  list.add(1);
  list.remove(0);
}
