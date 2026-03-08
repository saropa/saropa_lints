// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: prefer_const_declarations
// Test fixture for: prefer_descriptive_variable_names (v4)
// Source: lib/src/rules/stylistic/stylistic_additional_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

// ---------------------------------------------------------------------------
// BAD: Short variable name in a large block (>5 statements) — SHOULD trigger
// ---------------------------------------------------------------------------

void _badLargeBlock() {
  // expect_lint: prefer_descriptive_variable_names
  final ab = 'hello';
  final name = 'world';
  final value1 = 1;
  final value2 = 2;
  final value3 = 3;
  final value4 = 4;
}

// ---------------------------------------------------------------------------
// GOOD: Short variable name in a small block (<=5 statements)
// ---------------------------------------------------------------------------

void _goodSmallBlock() {
  final ab = 'hello';
  final name = 'world';
  final value1 = 1;
}

int? _goodTakePattern() {
  final r = 42;
  return r;
}

// ---------------------------------------------------------------------------
// GOOD: Allowed short names (always OK regardless of block size)
// ---------------------------------------------------------------------------

void _goodAllowedNames() {
  final id = 1;
  final db = 'database';
  final io = 'input';
  final ui = 'interface';
  final x = 0;
  final y = 1;
  final z = 2;
  final i = 10;
  final j = 20;
  final k = 30;
  final e = 'error';
  final n = 100;
}

// ---------------------------------------------------------------------------
// GOOD: Private names (always OK)
// ---------------------------------------------------------------------------

void _goodPrivateNames() {
  final _a = 1;
  final _b = 2;
  final name1 = 3;
  final name2 = 4;
  final name3 = 5;
  final name4 = 6;
}

// ---------------------------------------------------------------------------
// GOOD: Names >= 3 characters (always OK)
// ---------------------------------------------------------------------------

void _goodLongNames() {
  final abc = 1;
  final foo = 2;
  final bar = 3;
}

// ---------------------------------------------------------------------------
// GOOD: C-style for-loop index variables (always OK)
// ---------------------------------------------------------------------------

void _goodForLoopIndex() {
  for (var ii = 0; ii < 10; ii++) {
    // 'ii' would normally be flagged at 2 chars, but for-loop exemption
  }
}
