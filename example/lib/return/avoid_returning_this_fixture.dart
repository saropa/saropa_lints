// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_returning_this` lint rule.

// BAD: Return this for chaining (can confuse or encourage mutable APIs)
// expect_lint: avoid_returning_this
class Bad {
  Bad copy() => this;
}

// GOOD: Return new instance or void
class Good {
  void update() {}
}

void main() {}
