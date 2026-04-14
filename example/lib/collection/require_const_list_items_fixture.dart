// ignore_for_file: unused_element
// Test fixture for: require_const_list_items
// BAD: no-arg constructor in list without const
// expect_lint: require_const_list_items
void bad() {
  final list = [Box(), Box()];
}

// GOOD: const constructor
void good() {
  final list = [const Box(), Box()];
}

class Box {
  const Box();
}
