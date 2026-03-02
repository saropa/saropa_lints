// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_freezed_union_types` lint rule.

// BAD: Union without freezed union typing
// expect_lint: prefer_freezed_union_types
sealed class Result {}
class Ok extends Result {}
class Err extends Result {}

// GOOD: Freezed union types
// @freezed
// sealed class Result with _$Result {
//   factory Result.ok() = Ok;
//   factory Result.err(String msg) = Err;
// }

void main() {}
