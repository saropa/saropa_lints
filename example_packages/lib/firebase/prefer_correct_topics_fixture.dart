// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `prefer_correct_topics` lint rule.

// BAD: Invalid or unsafe FCM topic name
// expect_lint: prefer_correct_topics
const badTopic = 'user/123'; // slashes not allowed

// GOOD: Valid topic format
const goodTopic = 'user_123';

void main() {}
