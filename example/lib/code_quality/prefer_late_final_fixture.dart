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

// GOOD: assigning method is also passed as a tear-off elsewhere in the
// class (e.g. the setState(callback) pattern) — the tear-off may run any
// number of times at runtime, so the field cannot be safely made final
// even though only one direct call site is visible in the AST.
class _GoodPreferLateFinalTearOffCallSite {
  late int value; // Reassigned via _refresh()'s tear-off call, not just init()
  void init() {
    _refresh();
  }

  void _refresh() {
    value = 42;
  }

  void onTap() {
    scheduleCallback(_refresh);
  }

  void scheduleCallback(void Function() callback) => callback();
}
