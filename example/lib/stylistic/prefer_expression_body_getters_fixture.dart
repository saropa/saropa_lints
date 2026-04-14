// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_expression_body_getters` lint rule.

// BAD: Getter with block body and single return
// expect_lint: prefer_expression_body_getters
int get value {
  return 1;
}

// GOOD: Expression body getter
int get valueGood => 1;

void main() {}
