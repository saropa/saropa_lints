// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_single_cascade_in_expression_statements` lint rule.

// BAD: Single cascade as statement
// expect_lint: avoid_single_cascade_in_expression_statements
void bad() {
  final list = <int>[];
  list..add(1);
}

// GOOD: Direct call
void good() {
  final list = <int>[];
  list.add(1);
}

void main() {}
