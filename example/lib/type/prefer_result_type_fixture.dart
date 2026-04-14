// ignore_for_file: unused_element
// Test fixture for: prefer_result_type
// BAD: no return type
// expect_lint: prefer_result_type
foo() => 1;

// GOOD: explicit return type
int bar() => 2;
