// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_class_destructuring` lint rule.

// BAD: Repeated property access instead of destructuring
// expect_lint: prefer_class_destructuring
void bad((int a, int b) r) {
  final x = r.$1;
  final y = r.$2;
}

// GOOD: Destructuring
void good((int a, int b) r) {
  final (a, b) = r;
}

void main() {}
