// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_correct_json_casts` lint rule.

// BAD: Incorrect cast from JSON to DateTime
// expect_lint: prefer_correct_json_casts
DateTime bad(Map<String, dynamic> json) => json['at'] as DateTime;

// GOOD: Parse ISO string to DateTime
DateTime good(Map<String, dynamic> json) => DateTime.parse(json['at'] as String);

void main() {}
