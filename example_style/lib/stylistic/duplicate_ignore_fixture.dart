// Test fixture for: duplicate_ignore
// BAD: same diagnostic listed twice in one ignore comment triggers the lint.
// GOOD: no duplicate in the same comment does not.

// LINT: duplicate_ignore
// ignore: rule_a, rule_a

// OK
// ignore: rule_a, rule_b

void main() {}
