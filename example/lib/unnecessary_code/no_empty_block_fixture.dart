// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `no_empty_block` lint rule.

// BAD: Should trigger no_empty_block
void _bad1340() {
  // expect_lint: no_empty_block
  if (true) {} // Empty block with no statements
}

// GOOD: Should NOT trigger no_empty_block
void _good1340() {
  if (true) {
    // intentionally empty
  }
}

void main() {}
