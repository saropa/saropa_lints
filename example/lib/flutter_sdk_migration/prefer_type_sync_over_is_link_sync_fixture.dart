// ignore_for_file: unused_element
// Test fixture for: prefer_type_sync_over_is_link_sync
// Source: lib/src/rules/config/flutter_sdk_migration_rules.dart

import 'dart:io';

bool isLinkSyncBad(String path) {
  // expect_lint: prefer_type_sync_over_is_link_sync
  return FileSystemEntity.isLinkSync(path);
}

bool isLinkSyncGood(String path) {
  return FileSystemEntity.typeSync(path, followLinks: false) ==
      FileSystemEntityType.link;
}

bool isLinkSyncFalsePositive(String path) {
  return _LinkChecker().isLinkSync(path);
}

class _LinkChecker {
  bool isLinkSync(String path) => false;
}
