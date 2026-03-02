// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_final_fields_always` lint rule.

// BAD: Non-final field that could be final
// expect_lint: prefer_final_fields_always
class Bad {
  int value = 0;
}

// GOOD: Final field
class Good {
  final int value;
  Good(this.value);
}

void main() {}
