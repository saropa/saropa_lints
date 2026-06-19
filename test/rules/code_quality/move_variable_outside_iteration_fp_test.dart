// Oracle-backed regression tests for `move_variable_outside_iteration`.
//
// Guards the data-flow fix for the false positive where the rule flagged a
// loop-body declaration whose initializer reads a local reassigned later in the
// loop (an ancestor-walk / accumulator pattern). Hoisting such a declaration
// freezes it at the first iteration's value and breaks the loop, so it must NOT
// be flagged. The harness resolves dart:core / dart:io so `RegExp(...)`,
// `File(...)`, and `Directory(...)` become InstanceCreationExpression (the shape
// the rule keys on) — the same form the real custom_lint run sees.
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_variables_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

const String _rule = 'move_variable_outside_iteration';

void main() {
  group('move_variable_outside_iteration data-flow guard', () {
    test('NO lint: ancestor walk reads `dir` reassigned in the loop', () async {
      const String code = '''
import 'dart:io';

void f() {
  Directory dir = Directory.current.absolute;
  while (true) {
    final configFile = File('\${dir.path}/.dart_tool/package_config.json');
    print(configFile.path);
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
}
''';
      final codes = await reportedRuleCodes(
        MoveVariableOutsideIterationRule(),
        code,
      );
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: reads the for counter mutated by the updater', () async {
      const String code = '''
import 'dart:io';

void f() {
  for (int i = 0; i < 10; i++) {
    final segment = File('segment\$i');
    print(segment.path);
  }
}
''';
      final codes = await reportedRuleCodes(
        MoveVariableOutsideIterationRule(),
        code,
      );
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: reads `j` mutated by `j++` in the body', () async {
      const String code = '''
import 'dart:io';

void f() {
  int j = 0;
  while (j < 10) {
    final entry = File('value\$j');
    print(entry.path);
    j++;
  }
}
''';
      final codes = await reportedRuleCodes(
        MoveVariableOutsideIterationRule(),
        code,
      );
      expect(codes, isNot(contains(_rule)));
    });

    test('LINT: genuine invariant constructor over a literal', () async {
      const String code = '''
void f() {
  for (int i = 0; i < 10; i++) {
    final regex = RegExp(r'\\d+');
    print(regex.hasMatch('\$i'));
  }
}
''';
      final codes = await reportedRuleCodes(
        MoveVariableOutsideIterationRule(),
        code,
      );
      expect(codes, contains(_rule));
    });

    test('LINT: constructor with no arguments stays invariant', () async {
      const String code = '''
void f() {
  for (int i = 0; i < 10; i++) {
    final buffer = StringBuffer();
    buffer.write('\$i');
  }
}
''';
      final codes = await reportedRuleCodes(
        MoveVariableOutsideIterationRule(),
        code,
      );
      expect(codes, contains(_rule));
    });

    test('LINT: interpolation reads only a loop-invariant local', () async {
      const String code = '''
import 'dart:io';

void f() {
  final String base = Directory.current.path;
  for (int i = 0; i < 10; i++) {
    final entry = File('\$base/config.json');
    print(entry.path);
  }
}
''';
      final codes = await reportedRuleCodes(
        MoveVariableOutsideIterationRule(),
        code,
      );
      expect(codes, contains(_rule));
    });
  });
}
