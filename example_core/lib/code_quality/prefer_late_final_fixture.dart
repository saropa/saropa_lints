// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_late_final` lint rule.

// BAD: Should trigger prefer_late_final
// expect_lint: prefer_late_final
class _BadPreferLateFinal {
  late int value; // Assigned once — should be late final
  void init() {
    value = 42;
  }
}

// GOOD: Should NOT trigger prefer_late_final
class _GoodPreferLateFinal {
  late final int value; // final guarantees single assignment
  void init() {
    value = 42;
  }
}
