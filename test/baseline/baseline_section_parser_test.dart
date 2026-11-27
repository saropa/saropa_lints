// Tests for the `baseline:` section line parser: trailing comments, inline
// (flow) lists and block lists, as used by the documented examples. The
// earlier parser kept `# comments` in values and read `[info]` as a string,
// so a commented `file:` named a missing file and `only_impacts: [info]`
// baselined every severity.
library;

import 'package:saropa_lints/src/baseline/baseline_config.dart';
import 'package:saropa_lints/src/baseline/baseline_section_parser.dart';
import 'package:test/test.dart';

/// Parses [body] as the lines after a top-level `baseline:` header.
Map<String, Object> _parse(String body) {
  final String content = 'baseline:\n$body';
  return parseBaselineSection(content, 'baseline:'.length);
}

void main() {
  group('parseBaselineSection', () {
    test('reads the documented example with trailing comments', () {
      final Map<String, Object> map = _parse('''
  file: "saropa_baseline.json"    # Specific violations
  date: "2025-01-15"              # Code unchanged since this date
  paths:                          # Directories/patterns
    - "lib/legacy/"   # old code
    - **/generated/
  only_impacts: [info, warning]   # Only baseline these severities
''');
      expect(map['file'], 'saropa_baseline.json');
      expect(map['date'], '2025-01-15');
      expect(map['paths'], <String>['lib/legacy/', '**/generated/']);
      expect(map['only_impacts'], <String>['info', 'warning']);

      // End to end through BaselineConfig: the values are usable.
      final BaselineConfig config = BaselineConfig.fromYaml(map);
      expect(config.file, 'saropa_baseline.json');
      expect(config.date, DateTime(2025, 1, 15));
      expect(config.shouldBaselineImpact('info'), isTrue);
      expect(config.shouldBaselineImpact('error'), isFalse);
    });

    test('reads a single-item flow list (configuration guide example)', () {
      final Map<String, Object> map = _parse('''
  file: "saropa_baseline.json"
  only_impacts: [info] # Still see errors and warnings
''');
      expect(map['only_impacts'], <String>['info']);
      expect(
        BaselineConfig.fromYaml(map).shouldBaselineImpact('warning'),
        isFalse,
      );
    });

    test('flow lists: quoted items, empty list, comma inside quotes', () {
      final Map<String, Object> map = _parse('''
  paths: ["lib/a/", 'lib/b/']
  only_impacts: []
  other: ["a,b", c]
''');
      expect(map['paths'], <String>['lib/a/', 'lib/b/']);
      expect(map['only_impacts'], isEmpty);
      expect(map['other'], <String>['a,b', 'c']);
    });

    test('keeps # that is not a comment', () {
      final Map<String, Object> map = _parse('''
  file: "dir #1/b.json"
  date: 2025-01-15
  paths:
    - lib/#legacy
''');
      expect(map['file'], 'dir #1/b.json');
      expect(map['date'], '2025-01-15');
      expect(map['paths'], <String>['lib/#legacy']);
    });

    test('stops at the next top-level key and handles CRLF', () {
      final Map<String, Object> map = parseBaselineSection(
        'baseline:\r\n  file: b.json\r\nmax_issues: 5\r\n  date: x\r\n',
        'baseline:'.length,
      );
      expect(map, <String, Object>{'file': 'b.json'});
    });

    test('a bare key with no items is an empty list', () {
      final Map<String, Object> map = _parse('  paths:\n  file: b.json\n');
      expect(map['paths'], isEmpty);
      expect(map['file'], 'b.json');
    });
  });

  group('YAML scalar helpers', () {
    test('stripYamlComment', () {
      expect(stripYamlComment('a # c'), 'a');
      expect(stripYamlComment('"a # b" # c'), '"a # b"');
      expect(stripYamlComment('a#b'), 'a#b');
      expect(stripYamlComment('# only'), '');
    });

    test('unquoteYamlScalar removes only a matching pair', () {
      expect(unquoteYamlScalar('"a"'), 'a');
      expect(unquoteYamlScalar("'a'"), 'a');
      expect(unquoteYamlScalar('"a\''), '"a\'');
      expect(unquoteYamlScalar('a"b'), 'a"b');
    });
  });

  group('BaselineConfig only_impacts legacy names', () {
    test('map onto the three severities', () {
      final BaselineConfig config = BaselineConfig.fromYaml(<String, Object>{
        'file': 'b.json',
        'only_impacts': <String>['low', 'medium', 'opinionated'],
      });
      expect(config.onlyImpacts, <String>['info', 'warning']);
      expect(config.shouldBaselineImpact('info'), isTrue);
      expect(config.shouldBaselineImpact('warning'), isTrue);
      expect(config.shouldBaselineImpact('error'), isFalse);
    });

    test('critical maps to error; current names pass through', () {
      final BaselineConfig config = BaselineConfig.fromYaml(<String, Object>{
        'only_impacts': <String>['Critical', 'info'],
      });
      expect(config.onlyImpacts, <String>['error', 'info']);
    });
  });
}
