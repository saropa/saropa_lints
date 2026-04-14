// ignore_for_file: unused_element
// Fixture for avoid_types_on_closure_parameters.
// Rule: avoid explicit types on closure parameters when inferrable.

void useList(List<int> list) {
  // LINT: explicit type on closure parameter
  list.map((int x) => x + 1);

  // OK: no type
  list.map((x) => x + 1);
}
