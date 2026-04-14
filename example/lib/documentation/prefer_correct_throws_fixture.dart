// ignore_for_file: unused_element
// Test fixture for: prefer_correct_throws
// BAD: throws but no @Throws
// expect_lint: prefer_correct_throws
void loadUser(String id) {
  if (id.isEmpty) throw ArgumentError('id');
}

// GOOD: has @Throws (would need package or custom annotation to resolve)
class _Placeholder {
  void ok() {}
}
