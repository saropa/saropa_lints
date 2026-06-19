// ignore_for_file: unused_local_variable, depend_on_referenced_packages
// Test fixture for: require_platform_check (conditional-IMPORT branch)
// Source: lib\src\rules\config\platform_rules.dart
//
// This file is the `if (dart.library.io)` branch of the conditional import in
// cond_import_entry.dart. It is never loaded on web (the web build resolves to
// cond_import_web.dart), so the dart:io usage below needs no kIsWeb guard.
// require_platform_check must NOT fire here — the file split IS the guard.
import 'dart:io';

// GOOD: native-only file reached via `if (dart.library.io)` — expect NO lint.
void serve() {
  final file = File('data.txt');
  file.writeAsStringSync('Hello');
}
