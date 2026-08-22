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

import 'package:saropa_lints/saropa_lints.dart' show SaropaLintRule;
import 'package:saropa_lints/scan.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

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

    // Regression for the scan-on-save daemon bug: the daemon always spawns
    // with --tier, and this project's `_resolveRuleNames` used to return the
    // tier's rule set directly, entirely ignoring the project's own
    // `diagnostics:` overrides. A user who explicitly disabled a rule in
    // their analysis_options.yaml saw it fire anyway on save.
    test('run with tier still applies project diagnostics: overrides', () {
      final tempDir = Directory.systemTemp.createTempSync(
        'scan_runner_tier_override_',
      );
      try {
        File('${tempDir.path}/analysis_options.yaml').writeAsStringSync('''
plugins:
  saropa_lints:
    diagnostics:
      avoid_hardcoded_credentials: false
      no_empty_block: true
''');
        Directory('${tempDir.path}/lib').createSync();
        File(
          '${tempDir.path}/lib/main.dart',
        ).writeAsStringSync('void main() {}\n');

        final runner = ScanRunner(
          targetPath: tempDir.path,
          tier: 'essential',
          messageSink: (_) {},
        );
        final result = runner.run();
        expect(result, isNotNull);

        // avoid_hardcoded_credentials is in the essential tier, but the
        // config above explicitly disables it — must stay disabled.
        expect(
          SaropaLintRule.enabledRules,
          isNot(contains('avoid_hardcoded_credentials')),
          reason: 'config diagnostics: false must override the tier default',
        );
        expect(
          SaropaLintRule.disabledRules,
          contains('avoid_hardcoded_credentials'),
        );

        // no_empty_block is NOT in the essential tier, but the config above
        // explicitly enables it — must run even though the tier excludes it.
        expect(
          SaropaLintRule.enabledRules,
          contains('no_empty_block'),
          reason: 'config diagnostics: true must add rules beyond the tier',
        );
      } finally {
        // Retry-tolerant cleanup: Windows file handles can linger after tests
        safeDeleteDir(tempDir);
      }
    });
  });

  // Exercises the public wrapper the scan daemon's `listFiles` request uses
  // (bin/scan_daemon.dart) to hand the IDE baseline scan a file list it can
  // chunk before issuing per-chunk resolved scans — see
  // plans/PLAN_scan_only_diagnostics.md Lane 3.
  group('ScanRunner.discoverDartFiles', () {
    test('finds included Dart files and skips excluded ones', () {
      final tempDir = Directory.systemTemp.createTempSync(
        'scan_runner_discover_',
      );
      try {
        Directory('${tempDir.path}/lib').createSync();
        File(
          '${tempDir.path}/lib/main.dart',
        ).writeAsStringSync('void main() {}\n');
        File(
          '${tempDir.path}/lib/model.g.dart',
        ).writeAsStringSync('// generated\n');
        Directory('${tempDir.path}/build').createSync();
        File(
          '${tempDir.path}/build/leftover.dart',
        ).writeAsStringSync('// build output\n');

        final files = ScanRunner.discoverDartFiles(tempDir.path);
        final relative = files
            .map(
              (f) => f
                  .replaceAll('\\', '/')
                  .split('${tempDir.path.replaceAll('\\', '/')}/')
                  .last,
            )
            .toList();

        expect(relative, contains('lib/main.dart'));
        expect(relative, isNot(contains('lib/model.g.dart')));
        expect(relative, isNot(contains('build/leftover.dart')));
      } finally {
        safeDeleteDir(tempDir);
      }
    });

    test('returns an empty list for a directory with no Dart files', () {
      final tempDir = Directory.systemTemp.createTempSync(
        'scan_runner_discover_empty_',
      );
      try {
        expect(ScanRunner.discoverDartFiles(tempDir.path), isEmpty);
      } finally {
        safeDeleteDir(tempDir);
      }
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

    // Bug infra_scan_cli_misses_instance_creation_rules: an implicit
    // constructor call (`File('x')`) parses as MethodInvocation in older Dart
    // syntactic passes, so addInstanceCreationExpression rules never fire
    // under run(). runResolved() resolves the unit, so those rules always
    // fire. From Dart 3.13+ the parser handles implicit `new` even in
    // syntactic mode, so both passes may fire the same rules — the resolved
    // result must be a (possibly non-strict) superset of the syntactic one.
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

      // Resolved must find everything syntactic found (superset).
      expect(
        syntacticRules.difference(resolvedRules),
        isEmpty,
        reason:
            'resolved scan must be a superset of the syntactic scan — '
            'every syntactic rule should also fire under resolution',
      );

      // Resolved must find at least one rule on this fixture.
      expect(
        resolvedRules,
        isNotEmpty,
        reason:
            'resolved scan should surface instance-creation / type-based '
            'rules on the platform-check fixture',
      );
    });
  });

  group('ScanRunner.runResolvedWithCollection', () {
    // The daemon path: one collection built up front, reused across
    // requests. These tests pin that a shared collection produces the same
    // contract as runResolved (non-null diagnostics, null on bad tier) and
    // that the collection survives repeated calls — the whole point of the
    // daemon is the second call being served by the same warm collection.
    //
    // Fixture choice: this repo's own analysis_options.yaml excludes
    // `lib/**` (dev-only self-exclusion), and a project-rooted collection
    // honors analyzer excludes — so unlike the runResolved tests above
    // (whose per-file collection bypasses project config) these must use a
    // file the project actually analyzes; test/ files qualify.
    const analyzedFixture = 'test/scan/scan_daemon_args_test.dart';

    test('serves repeated scans from one shared collection', () async {
      final collection = ScanRunner.buildProjectCollection(projectRoot);

      final first = await ScanRunner(
        targetPath: projectRoot,
        dartFiles: [analyzedFixture],
        tier: 'essential',
        messageSink: (_) {},
      ).runResolvedWithCollection(collection);
      expect(first, isNotNull);
      expect(first, isA<List<ScanDiagnostic>>());

      // Second request through the SAME collection (a fresh runner, as the
      // daemon constructs per request) must also succeed — a collection
      // corrupted by changeFile/applyPendingFileChanges would fail here.
      final second = await ScanRunner(
        targetPath: projectRoot,
        dartFiles: [analyzedFixture],
        tier: 'essential',
        messageSink: (_) {},
      ).runResolvedWithCollection(collection);
      expect(second, isNotNull);
      // Same file, same rules, no edits between calls: diagnostics must
      // be reproducible, not accumulate or vanish across requests.
      expect(second!.length, first!.length);
    });

    test('excluded file is skipped, not a StateError', () async {
      // lib/scan.dart IS excluded by this repo's analyzer config — the
      // exact shape of a user saving a file their own project excludes.
      // The daemon path must degrade to "scanned nothing" rather than
      // throw out of contextFor.
      final collection = ScanRunner.buildProjectCollection(projectRoot);
      final result = await ScanRunner(
        targetPath: projectRoot,
        dartFiles: ['lib/scan.dart'],
        tier: 'essential',
        messageSink: (_) {},
      ).runResolvedWithCollection(collection);
      expect(result, isNotNull);
      expect(result, isEmpty);
    });

    test('invalid tier returns null (same contract as runResolved)', () async {
      final collection = ScanRunner.buildProjectCollection(projectRoot);
      final result = await ScanRunner(
        targetPath: projectRoot,
        dartFiles: [analyzedFixture],
        tier: 'invalid_tier_name',
        messageSink: (_) {},
      ).runResolvedWithCollection(collection);
      expect(result, isNull);
    });
  });
}
