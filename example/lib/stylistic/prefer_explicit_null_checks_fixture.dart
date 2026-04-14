// ignore_for_file: unused_element
// Fixture for prefer_explicit_null_checks: prefer == null / != null over !.

void f(bool? b) {
  // LINT: bang operator
  if (b!) return;

  // OK: explicit null check
  if (b == null) return;
  if (b != null) return;
}
