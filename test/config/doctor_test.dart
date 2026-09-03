/// Tests for the `doctor` CLI's diagnostic logic.
///
/// Uses the extracted `diagnose()` function to verify issue detection
/// without touching the filesystem or exit codes.
library;

import 'package:test/test.dart';

// Import the diagnose function from the doctor CLI entry point.
// ignore: avoid_relative_lib_imports
import '../../bin/doctor.dart' show diagnose;

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
      const yaml = 'plugins:\n'
          '\tsaropa_lints:\n'
          '\t\tversion: "15.0.0"\n'
          '\t\tlog_level: info\n';
      final issues = diagnose(yaml, customExists: true);
      expect(issues.any((i) => i.contains('[log_level]')), isTrue);
    });
  });
}
