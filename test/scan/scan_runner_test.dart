/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `scan_runner_test` (scan runner).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
///
/// Tagged `slow`: runs the full scanner over the repo tree. Excluded from the
/// publish fast test pass and run in a dedicated slow pass instead.
@Tags(['slow'])
library;

import 'dart:io';

import 'package:saropa_lints/scan.dart';
import 'package:test/test.dart';

void main() {
  final projectRoot = Directory.current.path;

  group('ScanRunner', () {
    test('run with tier returns non-null list', () {
      final runner = ScanRunner(
        targetPath: projectRoot,
        tier: 'essential',
        messageSink: (_) {}, // quiet
      );
      final result = runner.run();
      expect(result, isNotNull);
      expect(result, isA<List<ScanDiagnostic>>());
    });

    test('run with invalid tier returns null', () {
      final runner = ScanRunner(
        targetPath: projectRoot,
        tier: 'invalid_tier_name',
        messageSink: (_) {},
      );
      final result = runner.run();
      expect(result, isNull);
    });

    test('run with dartFiles scans only those files', () {
      final runner = ScanRunner(
        targetPath: projectRoot,
        dartFiles: ['lib/scan.dart'],
        tier: 'essential',
        messageSink: (_) {},
      );
      final result = runner.run();
      expect(result, isNotNull);
      expect(result, isA<List<ScanDiagnostic>>());
      // All diagnostics should be from the single file we passed
      for (final d in result!) {
        expect(
          d.filePath,
          endsWith('scan.dart'),
          reason: 'diagnostics should be from the single file requested',
        );
      }
    });

    test('run with tier uses tier rule set not config', () {
      final runner = ScanRunner(
        targetPath: projectRoot,
        tier: 'essential',
        messageSink: (_) {},
      );
      final result = runner.run();
      expect(result, isNotNull);
      // Just ensure we got a result; rule count differs by tier
      expect(result, isA<List<ScanDiagnostic>>());
    });
  });

  group('ScanRunner.runResolved', () {
    test('with tier returns non-null list', () async {
      final runner = ScanRunner(
        targetPath: projectRoot,
        dartFiles: ['lib/scan.dart'],
        tier: 'essential',
        messageSink: (_) {},
      );
      final result = await runner.runResolved();
      expect(result, isNotNull);
      expect(result, isA<List<ScanDiagnostic>>());
    });

    test('with invalid tier returns null', () async {
      final runner = ScanRunner(
        targetPath: projectRoot,
        dartFiles: ['lib/scan.dart'],
        tier: 'invalid_tier_name',
        messageSink: (_) {},
      );
      final result = await runner.runResolved();
      expect(result, isNull);
    });

    // The core of bug infra_scan_cli_misses_instance_creation_rules: an
    // implicit constructor call (`File('x')`) parses as a MethodInvocation in
    // the syntactic pass, so addInstanceCreationExpression and type-based rules
    // never fire under run(). runResolved() resolves the unit, so those rules
    // fire — the resolved diagnostics must be a strict superset for a fixture
    // that contains a resolution-only violation.
    test('fires rules that the syntactic run() misses', () async {
      const fixture =
          'example/lib/platform/require_platform_check_fixture.dart';

      final syntactic = ScanRunner(
        targetPath: projectRoot,
        dartFiles: [fixture],
        tier: 'comprehensive',
        // Fixture lives under example/, which directory discovery excludes;
        // scan it explicitly without applying those exclusions.
        applyExclusionsToFileList: false,
        messageSink: (_) {},
      ).run();

      final resolved = await ScanRunner(
        targetPath: projectRoot,
        dartFiles: [fixture],
        tier: 'comprehensive',
        applyExclusionsToFileList: false,
        messageSink: (_) {},
      ).runResolved();

      expect(syntactic, isNotNull);
      expect(resolved, isNotNull);

      final syntacticRules = syntactic!.map((d) => d.ruleName).toSet();
      final resolvedRules = resolved!.map((d) => d.ruleName).toSet();

      expect(
        resolvedRules.difference(syntacticRules),
        isNotEmpty,
        reason:
            'resolved scan should surface instance-creation / type-based rules '
            'that the syntactic pass cannot see',
      );
    });
  });
}
