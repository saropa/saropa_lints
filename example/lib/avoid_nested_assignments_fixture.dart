// Test fixture for avoid_nested_assignments rule
// ignore_for_file: unused_local_variable, prefer_const_declarations
// ignore_for_file: prefer_final_locals, dead_code, unused_element
// ignore_for_file: avoid_variable_shadowing

int _next(int i) => i + 1;

int _getValue() => 42;

/// Standard for-loop update clauses - should NOT trigger
void forLoopUpdates() {
  const n = 10;
  const step = 3;

  for (int i = 0; i < n; i += 1) {}
  for (int i = 0; i < n; i += step) {}
  for (int i = n; i > 0; i -= 1) {}
  for (int i = 1; i < n; i *= 2) {}
  for (int i = 0; i < n; i = _next(i)) {}
  for (int mask = 1; mask != 0; mask <<= 1) {}
}

/// True nested assignments - SHOULD trigger
void nestedAssignments() {
  int x = 0;

  // expect_lint: avoid_nested_assignments
  if ((x = _getValue()) > 0) {}

  // expect_lint: avoid_nested_assignments
  _next(x = 5);

  // expect_lint: avoid_nested_assignments
  final list = [x = 5];
}

/// Standalone assignments - should NOT trigger
void standaloneAssignments() {
  int x = 0;
  x = _getValue();
  x += 1;
}
