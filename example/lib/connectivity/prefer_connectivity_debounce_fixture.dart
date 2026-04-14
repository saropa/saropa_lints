// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_connectivity_debounce` lint rule.

// BAD: Connectivity checked on every change without debounce
// expect_lint: prefer_connectivity_debounce
void bad(Stream<int> stream) {
  stream.listen((_) { /* check connectivity on every event */ });
}

// GOOD: Debounced connectivity checks
void good(Stream<int> stream) {
  stream.distinct(); // or use a debounce transformer
}

void main() {}
