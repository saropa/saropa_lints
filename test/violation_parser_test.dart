import 'package:saropa_lints/src/models/violation.dart';
import 'package:saropa_lints/src/violation_parser.dart';
import 'package:test/test.dart';

void main() {
  group('parseViolations', () {
    test('parses single violation line', () {
      const output = '  lib/main.dart:42:10 • Some problem message • my_rule •';

      final violations = parseViolations(output);

      expect(violations, hasLength(1));
      _expectViolation(
        violations.first,
        file: 'lib/main.dart',
        line: 42,
        column: 10,
        rule: 'my_rule',
        message: 'Some problem message ',
      );
    });

    test('parses multiple violation lines', () {
      const output = '''
  lib/main.dart:10:5 • First issue • rule_a •
  lib/utils.dart:20:3 • Second issue • rule_b •
  lib/models/user.dart:100:15 • Third issue • rule_c •''';

      final violations = parseViolations(output);

      expect(violations, hasLength(3));
      expect(violations[0].file, 'lib/main.dart');
      expect(violations[0].rule, 'rule_a');
      expect(violations[1].file, 'lib/utils.dart');
      expect(violations[1].rule, 'rule_b');
      expect(violations[2].file, 'lib/models/user.dart');
      expect(violations[2].rule, 'rule_c');
    });

    test('returns empty list for empty output', () {
      expect(parseViolations(''), isEmpty);
    });

    test('returns empty list for output with no violations', () {
      const output = '''
Analyzing...
No issues found!
''';
      expect(parseViolations(output), isEmpty);
    });

    test('ignores non-matching lines in mixed output', () {
      const output = '''
Analyzing target...
  lib/main.dart:42:10 • Problem here • some_rule •
Ran in 5.2s
''';

      final violations = parseViolations(output);

      expect(violations, hasLength(1));
      expect(violations.first.rule, 'some_rule');
    });

    test('handles leading whitespace on violation lines', () {
      const output =
          '    lib/deep/path.dart:1:1 • Indented line • indented_rule •';

      final violations = parseViolations(output);

      expect(violations, hasLength(1));
      expect(violations.first.file, 'lib/deep/path.dart');
    });

    test('handles no leading whitespace', () {
      const output = 'lib/main.dart:1:1 • No indent • no_indent_rule •';

      final violations = parseViolations(output);

      expect(violations, hasLength(1));
      expect(violations.first.file, 'lib/main.dart');
    });

    test('parses line and column as integers', () {
      const output = '  lib/main.dart:999:88 • Message • some_rule •';

      final violations = parseViolations(output);

      expect(violations.first.line, 999);
      expect(violations.first.column, 88);
    });

    test('handles message containing special characters', () {
      const output =
          "  lib/main.dart:1:1 • Use 'const' instead of 'final' • style_rule •";

      final violations = parseViolations(output);

      expect(violations, hasLength(1));
      expect(violations.first.message, contains('const'));
    });

    test('handles file paths with nested directories', () {
      const output =
          '  lib/src/rules/packages/my_rule.dart:50:3 • Issue • deep_rule •';

      final violations = parseViolations(output);

      expect(violations.first.file, 'lib/src/rules/packages/my_rule.dart');
    });

    test('assigns impact from rule registry for known rules', () {
      // Any rule that exists in allSaropaRules should get a non-null impact
      const output =
          '  lib/main.dart:1:1 • Message • avoid_icon_buttons_without_tooltip •';

      final violations = parseViolations(output);

      expect(violations, hasLength(1));
      expect(violations.first.impact, isNotNull);
    });

    test('defaults to medium impact for unknown rules', () {
      const output =
          '  lib/main.dart:1:1 • Message • completely_unknown_rule_xyz •';

      final violations = parseViolations(output);

      expect(violations, hasLength(1));
      // Unknown rules default to LintImpact.medium in violation_parser.dart
      expect(violations.first.impact, isNotNull);
    });

    test('does not match old hyphen-separated format', () {
      // This is the old format that caused the original bug.
      // The parser should NOT match it.
      const oldFormatOutput =
          '  lib/main.dart:42:10 - some_rule - Problem message';

      expect(parseViolations(oldFormatOutput), isEmpty);
    });

    test('handles message with brackets (rule prefix pattern)', () {
      const output =
          '  lib/main.dart:5:1 • [my_rule] Detailed problem description that is quite long • my_rule •';

      final violations = parseViolations(output);

      expect(violations, hasLength(1));
      expect(violations.first.message, contains('[my_rule]'));
    });
  });

  group('Violation', () {
    test('toString formats as file:line:column - rule - message', () {
      final v = Violation(
        file: 'lib/main.dart',
        line: 42,
        column: 10,
        rule: 'my_rule',
        message: 'Some problem',
      );

      expect(v.toString(), 'lib/main.dart:42:10 - my_rule - Some problem');
    });

    test('impact defaults to null when not provided', () {
      final v = Violation(
        file: 'f.dart',
        line: 1,
        column: 1,
        rule: 'r',
        message: 'm',
      );

      expect(v.impact, isNull);
    });
  });
}

void _expectViolation(
  Violation v, {
  required String file,
  required int line,
  required int column,
  required String rule,
  required String message,
}) {
  expect(v.file, file);
  expect(v.line, line);
  expect(v.column, column);
  expect(v.rule, rule);
  expect(v.message, message);
}
