// ignore_for_file: unused_element, unused_local_variable, dead_code
//
// Test fixture: Dart SDK 3.4 deprecated APIs (dart_sdk_34_deprecation_rules.dart)

import 'dart:io';

void badDeleteEventIsDirectory(FileSystemDeleteEvent event) {
  // expect_lint: avoid_deprecated_file_system_delete_event_is_directory
  final _ = event.isDirectory;
}
