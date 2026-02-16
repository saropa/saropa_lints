import 'dart:convert' show json;
import 'dart:io' show Directory, File, Platform;

import 'package:saropa_lints/src/report/analysis_reporter.dart';
import 'package:saropa_lints/src/report/report_consolidator.dart';
import 'package:saropa_lints/src/report/violation_export.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('violation_export_test_');
    projectRoot = tempDir.path;
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Helper to build ConsolidatedData with sensible defaults.
  ConsolidatedData buildData({
    ReportConfig? config,
    Map<LintImpact, List<ViolationRecord>>? violations,
    Map<String, String>? ruleSeverities,
    Map<String, int>? issuesByFile,
    Map<String, int>? issuesByRule,
    int filesAnalyzed = 10,
    int filesWithIssues = 3,
    int errorCount = 1,
    int warningCount = 2,
    int infoCount = 3,
    int batchCount = 1,
  }) {
    return ConsolidatedData(
      config: config ?? _defaultConfig(),
      filesAnalyzed: filesAnalyzed,
      filesWithIssues: filesWithIssues,
      errorCount: errorCount,
      warningCount: warningCount,
      infoCount: infoCount,
      issuesByFile: issuesByFile ?? const <String, int>{},
      issuesByRule: issuesByRule ?? const <String, int>{},
      ruleSeverities: ruleSeverities ?? const <String, String>{},
      violations: violations ?? const <LintImpact, List<ViolationRecord>>{},
      batchCount: batchCount,
    );
  }

  String exportPath() {
    final sep = Platform.pathSeparator;
    return '$projectRoot${sep}reports$sep.saropa_lints${sep}violations.json';
  }

  Map<String, dynamic> readExport() {
    final content = File(exportPath()).readAsStringSync();
    return json.decode(content) as Map<String, dynamic>;
  }

  group('ViolationExporter', () {
    test('writes valid JSON matching schema', () {
      final data = buildData();

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: '20260209_143022',
        data: data,
        owaspLookup: const <String, OwaspMapping>{},
      );

      final file = File(exportPath());
      expect(file.existsSync(), isTrue);

      final parsed = readExport();
      expect(parsed['schema'], '1.0');
      expect(parsed['sessionId'], '20260209_143022');
      expect(parsed.containsKey('timestamp'), isTrue);
      expect(parsed.containsKey('config'), isTrue);
      expect(parsed.containsKey('summary'), isTrue);
      expect(parsed.containsKey('violations'), isTrue);
    });

    test('schema version is 1.0', () {
      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(),
        owaspLookup: const <String, OwaspMapping>{},
      );

      expect(readExport()['schema'], '1.0');
    });

    test('zero violations writes file with empty array', () {
      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final parsed = readExport();
      final violations = parsed['violations'] as List<dynamic>;
      expect(violations, isEmpty);
    });

    test('all violations included regardless of maxIssues', () {
      // Config has maxIssues=1, but export should contain all 3
      final config = _defaultConfig(maxIssues: 1);
      final violations = <LintImpact, List<ViolationRecord>>{
        LintImpact.high: [
          _violation(rule: 'rule_a', file: 'lib/a.dart', line: 1),
          _violation(rule: 'rule_b', file: 'lib/b.dart', line: 2),
          _violation(rule: 'rule_c', file: 'lib/c.dart', line: 3),
        ],
      };

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(config: config, violations: violations),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final parsed = readExport();
      final exported = parsed['violations'] as List<dynamic>;
      expect(exported, hasLength(3));
    });

    test('maxIssuesNote explains the cap does not apply', () {
      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final configSection = readExport()['config'] as Map<String, dynamic>;
      expect(configSection['maxIssuesNote'], contains('IDE'));
    });

    test('path normalization converts Windows backslashes', () {
      final violations = <LintImpact, List<ViolationRecord>>{
        LintImpact.medium: [
          _violation(
            rule: 'test_rule',
            file: '$projectRoot\\lib\\main.dart',
            line: 10,
          ),
        ],
      };

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(violations: violations),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final exported = readExport()['violations'] as List<dynamic>;
      final filePath =
          (exported.first as Map<String, dynamic>)['file'] as String;
      expect(filePath, 'lib/main.dart');
      expect(filePath.contains('\\'), isFalse);
      expect(filePath.startsWith('/'), isFalse);
    });

    test('violations sorted by impact then file then line', () {
      final violations = <LintImpact, List<ViolationRecord>>{
        LintImpact.low: [_violation(rule: 'r1', file: 'lib/z.dart', line: 1)],
        LintImpact.critical: [
          _violation(rule: 'r2', file: 'lib/b.dart', line: 20),
          _violation(rule: 'r3', file: 'lib/a.dart', line: 5),
          _violation(rule: 'r4', file: 'lib/a.dart', line: 1),
        ],
      };

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(violations: violations),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final exported = readExport()['violations'] as List<dynamic>;
      expect(exported, hasLength(4));

      // Critical first, then sorted by file (a before b), then line
      final impacts = exported
          .map((v) => (v as Map<String, dynamic>)['impact'] as String)
          .toList();
      expect(impacts[0], 'critical');
      expect(impacts[1], 'critical');
      expect(impacts[2], 'critical');
      expect(impacts[3], 'low');

      // Within critical: a.dart:1, a.dart:5, b.dart:20
      final files = exported
          .take(3)
          .map((v) => (v as Map<String, dynamic>)['file'] as String)
          .toList();
      expect(files[0], 'lib/a.dart');
      expect(files[1], 'lib/a.dart');
      expect(files[2], 'lib/b.dart');

      final lines = exported
          .take(2)
          .map((v) => (v as Map<String, dynamic>)['line'] as int)
          .toList();
      expect(lines[0], 1);
      expect(lines[1], 5);
    });

    test('OWASP populated for security rules', () {
      final violations = <LintImpact, List<ViolationRecord>>{
        LintImpact.critical: [
          _violation(
            rule: 'avoid_hardcoded_credentials',
            file: 'lib/auth.dart',
            line: 5,
          ),
        ],
      };

      final owaspLookup = <String, OwaspMapping>{
        'avoid_hardcoded_credentials': const OwaspMapping(
          mobile: {OwaspMobile.m1},
          web: {OwaspWeb.a02, OwaspWeb.a07},
        ),
      };

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(violations: violations),
        owaspLookup: owaspLookup,
      );

      final exported = readExport()['violations'] as List<dynamic>;
      final owasp =
          (exported.first as Map<String, dynamic>)['owasp']
              as Map<String, dynamic>;

      final mobile = (owasp['mobile'] as List<dynamic>).cast<String>();
      final web = (owasp['web'] as List<dynamic>).cast<String>();

      expect(mobile, contains('m1'));
      expect(web, contains('a02'));
      expect(web, contains('a07'));
    });

    test('OWASP empty arrays for non-security rules', () {
      final violations = <LintImpact, List<ViolationRecord>>{
        LintImpact.low: [
          _violation(rule: 'prefer_const', file: 'lib/a.dart', line: 1),
        ],
      };

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(violations: violations),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final exported = readExport()['violations'] as List<dynamic>;
      final owasp =
          (exported.first as Map<String, dynamic>)['owasp']
              as Map<String, dynamic>;

      expect(owasp['mobile'], isEmpty);
      expect(owasp['web'], isEmpty);
    });

    test('correction field present when available', () {
      final violations = <LintImpact, List<ViolationRecord>>{
        LintImpact.medium: [
          _violation(
            rule: 'test_rule',
            file: 'lib/a.dart',
            line: 1,
            correction: 'Use const instead',
          ),
        ],
      };

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(violations: violations),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final exported = readExport()['violations'] as List<dynamic>;
      final v = exported.first as Map<String, dynamic>;
      expect(v['correction'], 'Use const instead');
    });

    test('correction field absent when not available', () {
      final violations = <LintImpact, List<ViolationRecord>>{
        LintImpact.medium: [
          _violation(rule: 'test_rule', file: 'lib/a.dart', line: 1),
        ],
      };

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(violations: violations),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final exported = readExport()['violations'] as List<dynamic>;
      final v = exported.first as Map<String, dynamic>;
      expect(v.containsKey('correction'), isFalse);
    });

    test('temp file cleaned up after successful write', () {
      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final sep = Platform.pathSeparator;
      final tmpFile = File(
        '$projectRoot${sep}reports$sep.saropa_lints${sep}violations.json.tmp',
      );
      expect(tmpFile.existsSync(), isFalse);
    });

    test('overwrite replaces previous export', () {
      // First write
      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'session_1',
        data: buildData(),
        owaspLookup: const <String, OwaspMapping>{},
      );

      expect(readExport()['sessionId'], 'session_1');

      // Second write overwrites
      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'session_2',
        data: buildData(),
        owaspLookup: const <String, OwaspMapping>{},
      );

      expect(readExport()['sessionId'], 'session_2');
    });

    test('summary counts match violation data', () {
      final violations = <LintImpact, List<ViolationRecord>>{
        LintImpact.critical: [
          _violation(rule: 'r1', file: 'lib/a.dart', line: 1),
        ],
        LintImpact.high: [
          _violation(rule: 'r2', file: 'lib/b.dart', line: 2),
          _violation(rule: 'r3', file: 'lib/c.dart', line: 3),
        ],
      };

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(violations: violations),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final summary = readExport()['summary'] as Map<String, dynamic>;
      expect(summary['totalViolations'], 3);

      final byImpact = summary['byImpact'] as Map<String, dynamic>;
      expect(byImpact['critical'], 1);
      expect(byImpact['high'], 2);
    });

    test('severity uses lowercase values', () {
      final violations = <LintImpact, List<ViolationRecord>>{
        LintImpact.critical: [
          _violation(rule: 'test_rule', file: 'lib/a.dart', line: 1),
        ],
      };

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(
          violations: violations,
          ruleSeverities: const {'test_rule': 'ERROR'},
        ),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final exported = readExport()['violations'] as List<dynamic>;
      final severity =
          (exported.first as Map<String, dynamic>)['severity'] as String;
      expect(severity, 'error');
    });

    test('config section includes enabledRuleCountNote', () {
      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final configSection = readExport()['config'] as Map<String, dynamic>;
      expect(configSection['enabledRuleCountNote'], contains('tier selection'));
    });

    test('config includes enabledRuleNames', () {
      final config = ReportConfig(
        version: '4.14.0',
        effectiveTier: 'comprehensive',
        enabledRuleCount: 3,
        enabledRuleNames: const ['rule_a', 'rule_b', 'rule_c'],
        enabledPlatforms: const [],
        disabledPlatforms: const [],
        enabledPackages: const [],
        disabledPackages: const [],
        userExclusions: const [],
        maxIssues: 1000,
        outputMode: 'both',
      );

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(config: config),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final configSection = readExport()['config'] as Map<String, dynamic>;
      final names = (configSection['enabledRuleNames'] as List<dynamic>)
          .cast<String>();
      expect(names, ['rule_a', 'rule_b', 'rule_c']);
    });

    test('config includes disabledPackages and userExclusions', () {
      final config = ReportConfig(
        version: '4.14.0',
        effectiveTier: 'comprehensive',
        enabledRuleCount: 10,
        enabledRuleNames: const [],
        enabledPlatforms: const ['ios'],
        disabledPlatforms: const [],
        enabledPackages: const ['firebase'],
        disabledPackages: const ['isar', 'hive'],
        userExclusions: const ['no_magic_numbers', 'prefer_const'],
        maxIssues: 1000,
        outputMode: 'both',
      );

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(config: config),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final configSection = readExport()['config'] as Map<String, dynamic>;
      final disabled = (configSection['disabledPackages'] as List<dynamic>)
          .cast<String>();
      expect(disabled, ['isar', 'hive']);

      final exclusions = (configSection['userExclusions'] as List<dynamic>)
          .cast<String>();
      expect(exclusions, ['no_magic_numbers', 'prefer_const']);
    });

    test('summary includes batchCount', () {
      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(batchCount: 4),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final summary = readExport()['summary'] as Map<String, dynamic>;
      expect(summary['batchCount'], 4);
    });

    test('summary includes issuesByFile with relativized keys', () {
      final byFile = {
        '$projectRoot/lib/a.dart': 5,
        '$projectRoot/lib/b.dart': 2,
      };

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(issuesByFile: byFile),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final summary = readExport()['summary'] as Map<String, dynamic>;
      final exported = summary['issuesByFile'] as Map<String, dynamic>;
      expect(exported['lib/a.dart'], 5);
      expect(exported['lib/b.dart'], 2);
      // Absolute paths should not appear
      expect(exported.keys.any((k) => k.contains(projectRoot)), isFalse);
    });

    test('summary includes issuesByRule', () {
      final byRule = {'avoid_print': 12, 'prefer_const': 3};

      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(issuesByRule: byRule),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final summary = readExport()['summary'] as Map<String, dynamic>;
      final exported = summary['issuesByRule'] as Map<String, dynamic>;
      expect(exported['avoid_print'], 12);
      expect(exported['prefer_const'], 3);
    });

    test('summary ruleSeverities uses lowercase values', () {
      ViolationExporter.write(
        projectRoot: projectRoot,
        sessionId: 'test_session',
        data: buildData(
          ruleSeverities: const {
            'rule_a': 'ERROR',
            'rule_b': 'WARNING',
            'rule_c': 'INFO',
          },
        ),
        owaspLookup: const <String, OwaspMapping>{},
      );

      final summary = readExport()['summary'] as Map<String, dynamic>;
      final severities = summary['ruleSeverities'] as Map<String, dynamic>;
      expect(severities['rule_a'], 'error');
      expect(severities['rule_b'], 'warning');
      expect(severities['rule_c'], 'info');
    });
  });
}

ReportConfig _defaultConfig({int maxIssues = 1000}) {
  return ReportConfig(
    version: '4.14.0',
    effectiveTier: 'comprehensive',
    enabledRuleCount: 1590,
    enabledRuleNames: const <String>[],
    enabledPlatforms: const <String>['ios', 'android'],
    disabledPlatforms: const <String>['macos', 'web'],
    enabledPackages: const <String>['firebase'],
    disabledPackages: const <String>[],
    userExclusions: const <String>[],
    maxIssues: maxIssues,
    outputMode: 'both',
  );
}

ViolationRecord _violation({
  required String rule,
  required String file,
  required int line,
  String message = 'Test violation message',
  String? correction,
}) {
  return ViolationRecord(
    rule: rule,
    file: file,
    line: line,
    message: message,
    correction: correction,
  );
}
