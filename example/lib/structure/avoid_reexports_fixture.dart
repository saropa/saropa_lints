// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: unnecessary_import, unused_import
// Test fixture for: avoid_reexports
// Source: lib/src/rules/architecture/structure_rules.dart

// expect_lint: avoid_reexports
export 'avoid_barrel_files_fixture.dart';

// GOOD: import the defining library where it is needed instead.
// import 'avoid_barrel_files_fixture.dart';
void _placeholderReexports() {}
