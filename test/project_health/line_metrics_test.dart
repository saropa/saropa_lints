/// Tests for the size scanner's line classifier.
///
/// Focuses on the ambiguous cases the dashboard relies on being correct:
/// comment markers inside string literals, nested/multiline block comments,
/// and trailing-newline line counting.
import 'package:saropa_lints/src/cli/project_health/line_metrics.dart';
import 'package:test/test.dart';

void main() {
  group('countLines basics', () {
    test('empty content has zero lines', () {
      final c = countLines('');
      expect(c.total, 0);
      expect(c.code, 0);
      expect(c.comment, 0);
      expect(c.blank, 0);
    });

    test('trailing newline does not inflate the line count', () {
      final c = countLines('final x = 1;\n');
      expect(c.total, 1);
      expect(c.code, 1);
    });

    test('blank lines counted as blank', () {
      final c = countLines('\n   \n');
      expect(c.total, 2);
      expect(c.blank, 2);
    });

    test('line and doc comments counted as comment', () {
      final c = countLines('// a\n/// b');
      expect(c.comment, 2);
      expect(c.code, 0);
    });

    test('code with a trailing comment counts as code', () {
      final c = countLines('final x = 1; // set x');
      expect(c.code, 1);
      expect(c.comment, 0);
    });
  });

  group('block comments', () {
    test('single-line block comment is comment', () {
      expect(countLines('/* c */').comment, 1);
    });

    test('code after a closing block comment is code', () {
      final c = countLines('/* c */ final x = 1;');
      expect(c.code, 1);
      expect(c.comment, 0);
    });

    test('multiline block comment counts every line as comment', () {
      final c = countLines('/* a\n b\n */');
      expect(c.total, 3);
      expect(c.comment, 3);
    });

    test('nested block comment stays balanced', () {
      // Dart block comments nest: this is one balanced comment, not code.
      final c = countLines('/* /* */ */');
      expect(c.comment, 1);
      expect(c.code, 0);
    });
  });

  group('comment markers inside strings are NOT comments', () {
    test('// inside a string is code', () {
      final c = countLines("final s = 'a//b';");
      expect(c.code, 1);
      expect(c.comment, 0);
    });

    test('/* inside a string does not open a block comment', () {
      final c = countLines("final s = '/*';\nfinal y = 2;");
      expect(c.code, 2);
      expect(c.comment, 0);
    });

    test('raw string contents are code', () {
      final c = countLines(r"final s = r'a//b';");
      expect(c.code, 1);
      expect(c.comment, 0);
    });

    test('multiline triple string with // inside is code, not comment', () {
      final c = countLines("final s = '''\n// inside\n''';");
      expect(c.total, 3);
      expect(c.code, 3);
      expect(c.comment, 0);
    });
  });
}
