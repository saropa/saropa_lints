// ignore_for_file: unused_element
// Fixture for prefer_if_else_over_guards: consecutive guard clauses.

// LINT: two consecutive guard clauses
void f(int x) {
  if (x < 0) return;
  if (x > 10) return;
  print(x);
}

// OK: single guard or if-else
void g(int x) {
  if (x < 0 || x > 10) return;
  print(x);
}
