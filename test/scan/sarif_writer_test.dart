/// Tests for sarif_writer.dart — SARIF 2.1.0 serialization of audit results.
///
/// Covers the field mapping contract from the task brief: empty input still
/// produces a valid SARIF shape, every diagnostic field lands in the right
/// SARIF location, duplicate rule names collapse to one `rules[]` entry, and
/// Windows backslash paths become POSIX forward-slash URIs (SARIF's `uri`
/// is a URI reference — backslashes would make the file spec-invalid).
library;

import 'package:saropa_lints/scan.dart';
import 'package:test/test.dart';

void main() {
  group('buildSarifReport', () {
    test('empty diagnostic list produces valid SARIF with empty results', () {
      final sarif = buildSarifReport(
        const [],
        rootPath: '/project',
        toolVersion: '1.0.0',
      );

      expect(sarif[r'$schema'], isNotEmpty);
      expect(sarif['version'], '2.1.0');
      final runs = sarif['runs'] as List<dynamic>;
      expect(runs, hasLength(1));
      final run = runs.first as Map<String, dynamic>;
      expect(run['results'], isEmpty);
      final driver =
          (run['tool'] as Map<String, dynamic>)['driver']
              as Map<String, dynamic>;
      expect(driver['name'], 'saropa_lints');
      expect(driver['version'], '1.0.0');
      expect(driver['rules'], isEmpty);
    });

    test('single diagnostic maps every field correctly', () {
      final diagnostic = <String, dynamic>{
        'filePath': '/project/lib/main.dart',
        'line': 10,
        'column': 3,
        'endLine': 10,
        'endColumn': 8,
        'ruleName': 'avoid_print',
        'severity': 'warning',
        'impact': 'warning',
        'problemMessage': 'Do not use print in production code.',
        'correctionMessage': 'Use a logger instead.',
        'tier': 'essential',
        'category': 'core',
      };

      final sarif = buildSarifReport(
        [diagnostic],
        rootPath: '/project',
        toolVersion: '1.0.0',
      );

      final run = (sarif['runs'] as List<dynamic>).first as Map<String, dynamic>;
      final rules = run['tool']['driver']['rules'] as List<dynamic>;
      expect(rules, hasLength(1));
      expect((rules.first as Map<String, dynamic>)['id'], 'avoid_print');

      final results = run['results'] as List<dynamic>;
      expect(results, hasLength(1));
      final result = results.first as Map<String, dynamic>;
      expect(result['ruleId'], 'avoid_print');
      expect(result['level'], 'warning');
      expect(
        (result['message'] as Map<String, dynamic>)['text'],
        'Do not use print in production code.',
      );

      final location =
          ((result['locations'] as List<dynamic>).first
                  as Map<String, dynamic>)['physicalLocation']
              as Map<String, dynamic>;
      expect(
        (location['artifactLocation'] as Map<String, dynamic>)['uri'],
        'lib/main.dart',
      );
      final region = location['region'] as Map<String, dynamic>;
      expect(region['startLine'], 10);
      expect(region['startColumn'], 3);
      expect(region['endLine'], 10);
      expect(region['endColumn'], 8);

      // tier/category are carried through in the properties bag.
      final properties = result['properties'] as Map<String, dynamic>;
      expect(properties['tier'], 'essential');
      expect(properties['category'], 'core');
    });

    test('multiple diagnostics with same ruleName yield one rules[] entry', () {
      final diagnostics = [
        <String, dynamic>{
          'filePath': '/project/lib/a.dart',
          'line': 1,
          'column': 1,
          'endLine': 1,
          'endColumn': 5,
          'ruleName': 'avoid_print',
          'severity': 'warning',
          'problemMessage': 'msg a',
        },
        <String, dynamic>{
          'filePath': '/project/lib/b.dart',
          'line': 2,
          'column': 1,
          'endLine': 2,
          'endColumn': 5,
          'ruleName': 'avoid_print',
          'severity': 'error',
          'problemMessage': 'msg b',
        },
      ];

      final sarif = buildSarifReport(
        diagnostics,
        rootPath: '/project',
        toolVersion: '1.0.0',
      );

      final run = (sarif['runs'] as List<dynamic>).first as Map<String, dynamic>;
      final rules = run['tool']['driver']['rules'] as List<dynamic>;
      expect(rules, hasLength(1));
      expect(run['results'], hasLength(2));
    });

    test('Windows backslash paths convert to forward-slash URIs', () {
      final diagnostic = <String, dynamic>{
        'filePath': r'C:\project\lib\sub\widget.dart',
        'line': 1,
        'column': 1,
        'endLine': 1,
        'endColumn': 2,
        'ruleName': 'avoid_print',
        'severity': 'info',
        'problemMessage': 'msg',
      };

      final sarif = buildSarifReport(
        [diagnostic],
        rootPath: r'C:\project',
        toolVersion: '1.0.0',
      );

      final run = (sarif['runs'] as List<dynamic>).first as Map<String, dynamic>;
      final result = (run['results'] as List<dynamic>).first as Map<String, dynamic>;
      final location =
          ((result['locations'] as List<dynamic>).first
                  as Map<String, dynamic>)['physicalLocation']
              as Map<String, dynamic>;
      final uri =
          (location['artifactLocation'] as Map<String, dynamic>)['uri']
              as String;

      expect(uri, isNot(contains(r'\')));
      expect(uri, 'lib/sub/widget.dart');
      // 'info' severity maps to SARIF's 'note' level.
      expect(result['level'], 'note');
    });
  });

  group('sarifLevelForSeverity', () {
    test('maps the three known severities and falls back for unknowns', () {
      expect(sarifLevelForSeverity('error'), 'error');
      expect(sarifLevelForSeverity('warning'), 'warning');
      expect(sarifLevelForSeverity('info'), 'note');
      expect(sarifLevelForSeverity('bogus'), 'warning');
      expect(sarifLevelForSeverity(null), 'warning');
    });
  });
}
