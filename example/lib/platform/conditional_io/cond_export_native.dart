// ignore_for_file: unused_local_variable, depend_on_referenced_packages
// Test fixture for: require_platform_check (conditional-EXPORT branch)
// Source: lib\src\rules\config\platform_rules.dart
//
// This file is the `if (dart.library.io)` branch of a conditional EXPORT (see
// cond_export_entry.dart). Covers Hypothesis B of the bug: the scanner must
// treat ExportDirective configurations the same as ImportDirective ones.
// require_platform_check must NOT fire here.
import 'dart:io';

// GOOD: native-only file reached via conditional `export` — expect NO lint.
void persist() {
  final dir = Directory('cache');
  dir.createSync();
}
