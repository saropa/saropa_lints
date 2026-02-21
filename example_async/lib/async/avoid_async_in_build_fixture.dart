// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `avoid_async_in_build` lint rule.

// BAD: Should trigger avoid_async_in_build
class _BadBuild {
  // expect_lint: avoid_async_in_build
  Future<void> build() async {} // async build method
}

// GOOD: Should NOT trigger avoid_async_in_build
class _GoodBuild {
  void build() {} // sync build method
}

void main() {}
