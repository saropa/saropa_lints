// ignore_for_file: unused_element, unused_local_variable
//
// GOOD / non-violation patterns for dart_sdk_34_deprecation_rules.dart
// (no expect_lint markers — these must not match the deprecated-API rules.)

import 'dart:io';

/// .isDirectory on FileSystemCreateEvent is NOT deprecated — only on
/// FileSystemDeleteEvent.
void goodCreateEventIsDirectory(FileSystemCreateEvent event) {
  final _ = event.isDirectory;
}

/// User-defined [FileSystemDeleteEvent] must not be flagged.
class FileSystemDeleteEvent {
  bool get isDirectory => true;
}

void goodUserDeleteEvent() {
  final _ = FileSystemDeleteEvent().isDirectory;
}
