// ignore_for_file: unused_element, undefined_annotation
// Test fixture for: avoid_freezed_invalid_annotation_target
// BAD: freezed on function (use real freezed package to resolve annotation)
// expect_lint: avoid_freezed_invalid_annotation_target
@freezed()
void freezedOnFunction() {}

// OK: freezed on class in real usage
class _Placeholder {}
