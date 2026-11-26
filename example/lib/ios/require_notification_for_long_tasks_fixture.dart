// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// Test fixture for: require_notification_for_long_tasks (BAD only).
//
// Do not name any of the rule's foreground/notification skip signals
// (`_foregroundOrNotificationSignals` in the rule source) anywhere in this
// file, comments included: the rule matches them as raw substrings of the file
// text and a single hit disables it for the whole file, which would make every
// expect_lint below silently pass. GOOD / false-positive cases live in
// `require_notification_for_long_tasks_no_lint_fixture.dart` and
// `require_notification_for_long_tasks_boundary_ok_fixture.dart`.

Future<void> uploadLargeFile(dynamic f) async {}
Future<void> uploadFile(dynamic f) async {}
// A generic name is only reported when the body can do long work.
Future<void> processAllUsers() async {
  for (var i = 0; i < 1000; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

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
