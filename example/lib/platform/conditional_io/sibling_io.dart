// ignore_for_file: unused_local_variable, depend_on_referenced_packages
// Test fixture for: require_platform_check (sibling-stub heuristic, option c)
// Source: lib\src\rules\config\platform_rules.dart
//
// This `*_io.dart` file has a sibling `*_stub.dart` (sibling_stub.dart) but no
// conditional directive in this fixture set references it directly. The naming
// convention alone marks it native-only, so require_platform_check must NOT
// fire here even without a resolvable conditional import/export.
import 'dart:io';

// GOOD: native-only by `*_io.dart` + `*_stub.dart` convention — expect NO lint.
void store() {
  final file = File('store.bin');
  file.writeAsBytesSync(const <int>[]);
}
