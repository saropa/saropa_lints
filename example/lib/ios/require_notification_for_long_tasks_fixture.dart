// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// Test fixture for: require_notification_for_long_tasks (BAD only).
//
// Do not add `showProgressNotification`, `onStatusUpdate`, `CircularProgressIndicator`,
// or other foreground/notification skip literals from the rule — they disable
// the entire rule for the file. GOOD / false-positive cases live in
// `require_notification_for_long_tasks_no_lint_fixture.dart` and
// `require_notification_for_long_tasks_boundary_ok_fixture.dart`.

Future<void> uploadLargeFile(dynamic f) async {}
Future<void> uploadFile(dynamic f) async {}
Future<void> processAllUsers() async {}

// BAD: long operation names with no file-level progress / notification signals
// expect_lint: require_notification_for_long_tasks
Future<void> badUploadLarge() async {
  await uploadLargeFile(null);
}

// expect_lint: require_notification_for_long_tasks
Future<void> badProcessAllUsers() async {
  await processAllUsers();
}

// expect_lint: require_notification_for_long_tasks
Future<void> badUploadFile() async {
  await uploadFile(null);
}
