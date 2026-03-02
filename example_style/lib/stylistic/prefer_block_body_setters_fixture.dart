// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_block_body_setters` lint rule.

int _x = 0;

// BAD: Setter with expression body
// expect_lint: prefer_block_body_setters
set value(int v) => _x = v;

// GOOD: Setter with block body
set valueGood(int v) {
  _x = v;
}

void main() {}
