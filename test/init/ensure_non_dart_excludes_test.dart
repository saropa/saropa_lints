import 'package:saropa_lints/src/init/config_writer.dart';
import 'package:test/test.dart';

void main() {
  group('ensureNonDartExcludes', () {
    test('adds missing excludes to existing exclude section', () {
      const input = '''
analyzer:
  exclude:
    - "**/*.g.dart"
''';
      final result = ensureNonDartExcludes(input);
      expect(result, contains('reports/**'));
      expect(result, contains('bugs/**'));
      expect(result, contains('docs/**'));
      expect(result, contains('**/*.g.dart'));
    });

    test('skips already-present excludes', () {
      const input = '''
analyzer:
  exclude:
    - "reports/**"
    - "bugs/**"
    - "docs/**"
    - "doc/**"
    - "output/**"
    - "plans/**"
    - "tmp/**"
''';
      final result = ensureNonDartExcludes(input);
      expect(result, input);
    });

    test('returns unchanged when no analyzer section exists', () {
      const input = '''
plugins:
  saropa_lints:
    version: "14.3.7"
''';
      final result = ensureNonDartExcludes(input);
      expect(result, input);
    });

    test('creates exclude section under analyzer when missing', () {
      const input = '''
analyzer:
  errors:
    todo: ignore
''';
      final result = ensureNonDartExcludes(input);
      expect(result, contains('exclude:'));
      expect(result, contains('reports/**'));
      expect(result, contains('errors:'));
    });

    test('returns empty string unchanged', () {
      expect(ensureNonDartExcludes(''), '');
    });

    test('adds only missing excludes when some already present', () {
      const input = '''
analyzer:
  exclude:
    - "reports/**"
''';
      final result = ensureNonDartExcludes(input);
      expect(result, contains('bugs/**'));
      expect(result, contains('docs/**'));
      // reports/** already present — should not be duplicated
      final reportsCount = 'reports/**'.allMatches(result).length;
      expect(reportsCount, 1);
    });
  });
}
