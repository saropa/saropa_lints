// ignore_for_file: unused_element
// Fixture for prefer_foreach: prefer for-in over .forEach().

// LINT: forEach used
void bad(List<int> items) {
  items.forEach((x) => print(x));
}

// OK: for-in
void good(List<int> items) {
  for (final x in items) print(x);
}
