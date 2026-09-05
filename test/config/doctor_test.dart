/// Tests for the `doctor` CLI's diagnostic logic.
///
/// Uses the extracted `diagnose()` function to verify issue detection
/// without touching the filesystem or exit codes.
library;

import 'package:test/test.dart';

// Import the diagnose function from the doctor CLI entry point.
// ignore: avoid_relative_lib_imports
import '../../bin/doctor.dart' show diagnose, issueToJson;

void main() {
  group('doctor diagnose', () {
    test('clean config reports no issues', () {
      const yaml = '''
plugins:
  saropa_lints:
    version: "15.2.12"
    diagnostics:
      include: all
''';
      final issues = diagnose(yaml, customExists: true);
      expect(issues, isEmpty);
    });

    test('detects log_level in plugin block', () {
      const yaml = '''
plugins:
  saropa_lints:
    version: "15.0.0"
    log_level: info
''';
      final issues = diagnose(yaml, customExists: true);
      expect(issues, hasLength(1));
      expect(issues.first, contains('[log_level]'));
    });

    test('detects rule_packs in plugin block', () {
      const yaml = '''
plugins:
  saropa_lints:
    version: "15.0.0"
    rule_packs:
      enabled:
        - riverpod
''';
      final issues = diagnose(yaml, customExists: true);
      expect(issues, hasLength(1));
      expect(issues.first, contains('[rule_packs]'));
    });

    test('detects multiple misplaced keys', () {
      const yaml = '''
plugins:
  saropa_lints:
    version: "15.0.0"
    log_level: debug
    lane: fast
    rule_packs:
      enabled:
        - drift
''';
      final issues = diagnose(yaml, customExists: true);
      // log_level, lane, rule_packs — 3 misplaced keys
      final keyIssues = issues
          .where((i) => i.contains('unsupported_option'))
          .toList();
      expect(keyIssues, hasLength(3));
    });

    test('does not flag keys outside the plugin block', () {
      // A top-level `log_level:` should NOT be flagged — only keys
      // nested inside `plugins > saropa_lints:` cause SDK warnings.
      const yaml = '''
log_level: info
plugins:
  saropa_lints:
    version: "15.0.0"
''';
      final issues = diagnose(yaml, customExists: true);
      expect(issues, isEmpty);
    });

    test('reports missing plugin entry', () {
      const yaml = '''
analyzer:
  strong-mode:
    implicit-casts: false
''';
      final issues = diagnose(yaml, customExists: true);
      expect(issues, hasLength(1));
      expect(issues.first, contains('[plugin]'));
    });

    test('reports missing version constraint', () {
      const yaml = '''
plugins:
  saropa_lints:
    diagnostics:
      include: all
''';
      final issues = diagnose(yaml, customExists: true);
      expect(issues, hasLength(1));
      expect(issues.first, contains('[version]'));
    });

    test('reports missing custom file', () {
      const yaml = '''
plugins:
  saropa_lints:
    version: "15.0.0"
''';
      final issues = diagnose(yaml, customExists: false);
      expect(issues, hasLength(1));
      expect(issues.first, contains('[custom_file]'));
    });

    test('handles tab-indented plugin block', () {
      // Tab indentation is non-standard but must not crash or false-positive.
      const yaml =
          'plugins:\n'
          '\tsaropa_lints:\n'
          '\t\tversion: "15.0.0"\n'
          '\t\tlog_level: info\n';
      final issues = diagnose(yaml, customExists: true);
      expect(issues.any((i) => i.contains('[log_level]')), isTrue);
    });
  });

  // WP2 (plans/PLAN_ext_ui_dart_deferred.md) `--format json` row schema.
  // `issueToJson` re-parses the SAME `[key] message` strings the tests above
  // already assert on, so these tests pin the structured shape without
  // duplicating `_diagnose`'s detection logic.
  group('issueToJson', () {
    test('splits the bracketed key from the message', () {
      final row = issueToJson(
        '[log_level] found under plugins > saropa_lints: in '
        'analysis_options.yaml — causes unsupported_option warning.',
      );
      expect(row['key'], 'log_level');
      expect(row['severity'], 'warning');
      expect(
        row['message'],
        'found under plugins > saropa_lints: in '
        'analysis_options.yaml — causes unsupported_option warning.',
      );
    });

    test('the [plugin] key is severity error — the plugin never loads', () {
      final row = issueToJson(
        '[plugin] saropa_lints not found under plugins: in '
        'analysis_options.yaml — the plugin will not load.',
      );
      expect(row['key'], 'plugin');
      expect(row['severity'], 'error');
    });

    test('an issue string with no bracket falls back gracefully', () {
      final row = issueToJson('unstructured message with no key');
      expect(row['key'], 'unknown');
      expect(row['message'], 'unstructured message with no key');
      expect(row['severity'], 'warning');
    });
  });
}
