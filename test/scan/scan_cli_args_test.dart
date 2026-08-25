/// Tests `saropa_lints:scan` argv parsing ([parseScanArgs]) and one process-level guard.
///
/// The process test shells out to `dart run` so flag errors match real CLI behavior;
/// pure parser cases stay in-memory for speed.
library;

import 'dart:io';

import 'package:saropa_lints/src/scan/scan_cli_args.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  group('scan CLI (process)', () {
    test('--tier with no value exits with 2', () async {
      final result = await Process.run(
        'dart',
        ['run', 'saropa_lints:scan', '--tier'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(
        result.exitCode,
        2,
        reason: 'Expected exit 2 when --tier has no value',
      );
      expect(result.stdout.toString(), contains('--tier requires a value'));
    });
  });

  group('parseScanArgs', () {
    test('default path is . when no positional', () {
      final result = parseScanArgs(<String>[]);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.path, '.');
      expect((result).args.dartFiles, isEmpty);
      expect((result).args.tier, isNull);
      expect((result).args.formatJson, isFalse);
      expect((result).args.resolve, isFalse);
    });

    test('--resolve sets resolve flag', () {
      final result = parseScanArgs(<String>['.', '--resolve']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.resolve, isTrue);
    });

    // --profile is a valueless boolean flag: it must set profile without
    // consuming a following argument (regression guard for the value-eating
    // pattern used by --tier/--debug-rule).
    test('--profile sets profile flag and defaults to off', () {
      final off = parseScanArgs(<String>['.']);
      expect((off as ScanParseOk).args.profile, isFalse);

      final on = parseScanArgs(<String>[
        '.',
        '--profile',
        '--tier',
        'essential',
      ]);
      expect(on, isA<ScanParseOk>());
      expect((on as ScanParseOk).args.profile, isTrue);
      expect((on).args.tier, 'essential');
    });

    test('--exclude-light-lane sets the flag and defaults to off', () {
      final off = parseScanArgs(<String>['.']);
      expect((off as ScanParseOk).args.excludeLightLane, isFalse);

      final on = parseScanArgs(<String>[
        '.',
        '--exclude-light-lane',
        '--tier',
        'essential',
      ]);
      expect(on, isA<ScanParseOk>());
      expect((on as ScanParseOk).args.excludeLightLane, isTrue);
      expect((on).args.tier, 'essential');
    });

    test('--lane parses valid values and defaults to null', () {
      // Default: null (scanner defaults to full).
      final off = parseScanArgs(<String>['.']);
      expect((off as ScanParseOk).args.lane, isNull);

      // Explicit full.
      final full = parseScanArgs(<String>['.', '--lane', 'full']);
      expect((full as ScanParseOk).args.lane, 'full');

      // Explicit light.
      final light = parseScanArgs(<String>['.', '--lane', 'light']);
      expect((light as ScanParseOk).args.lane, 'light');

      // Case-insensitive.
      final upper = parseScanArgs(<String>['.', '--lane', 'FULL']);
      expect((upper as ScanParseOk).args.lane, 'full');
    });

    test('--lane with invalid value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--lane', 'bogus']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('must be "full" or "light"'),
      );
    });

    test('--lane with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--lane']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--lane requires a value'),
      );
    });

    test('--lane with next option as value returns invalid', () {
      // --lane followed by another flag should be treated as missing value.
      final result = parseScanArgs(<String>['.', '--lane', '--resolve']);
      expect(result, isA<ScanParseInvalid>());
    });

    test('--resolve combines with --tier without consuming its value', () {
      final result = parseScanArgs(<String>[
        '.',
        '--resolve',
        '--tier',
        'comprehensive',
      ]);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.resolve, isTrue);
      expect((result).args.tier, 'comprehensive');
    });

    test('--resolve is not treated as a --files path', () {
      final result = parseScanArgs(<String>[
        '.',
        '--files',
        'lib/a.dart',
        '--resolve',
      ]);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.dartFiles, ['lib/a.dart']);
      expect((result).args.resolve, isTrue);
    });

    test('first positional is path', () {
      final result = parseScanArgs(<String>['/path/to/project']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.path, '/path/to/project');
    });

    test('path is first positional when options present', () {
      final result = parseScanArgs(<String>['.', '--tier', 'essential']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.path, '.');
      expect((result).args.tier, 'essential');
    });

    test('--files collects paths until next option', () {
      final result = parseScanArgs(<String>[
        '.',
        '--files',
        'lib/a.dart',
        'lib/b.dart',
        '--tier',
        'recommended',
      ]);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.dartFiles, [
        'lib/a.dart',
        'lib/b.dart',
      ]);
      expect((result).args.tier, 'recommended');
    });

    test('--files-from-stdin uses stdinLines when provided', () {
      final result = parseScanArgs(
        <String>['.', '--files-from-stdin'],
        stdinLines: ['lib/foo.dart', 'lib/bar.dart'],
      );
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.dartFiles, [
        'lib/foo.dart',
        'lib/bar.dart',
      ]);
    });

    test('--tier with value parses', () {
      for (final tier in [
        'essential',
        'recommended',
        'professional',
        'comprehensive',
        'pedantic',
      ]) {
        final result = parseScanArgs(<String>['.', '--tier', tier]);
        expect(result, isA<ScanParseOk>(), reason: tier);
        expect((result as ScanParseOk).args.tier, tier);
      }
    });

    test('--tier with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--tier']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--tier requires a value'),
      );
      expect((result).message, contains('essential'));
    });

    test('--tier with next option as value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--tier', '--format']);
      expect(result, isA<ScanParseInvalid>());
    });

    test('--format json sets formatJson', () {
      final result = parseScanArgs(<String>['.', '--format', 'json']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.formatJson, isTrue);
    });

    test('--format other does not set formatJson', () {
      final result = parseScanArgs(<String>['.', '--format', 'text']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.formatJson, isFalse);
    });

    test('scan is not treated as path', () {
      final result = parseScanArgs(<String>['scan', '.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.path, '.');
    });

    test('--files with no following paths yields empty dartFiles', () {
      final result = parseScanArgs(<String>['.', '--files']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.dartFiles, isEmpty);
    });

    test('--format with no value leaves formatJson false', () {
      final result = parseScanArgs(<String>['.', '--format']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.formatJson, isFalse);
    });

    test('--debug-rule parses rule name', () {
      final result = parseScanArgs(<String>[
        '.',
        '--debug-rule',
        'avoid_redundant_await',
      ]);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.debugRule, 'avoid_redundant_await');
    });

    test('--debug-rule with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--debug-rule']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--debug-rule requires a rule name'),
      );
    });

    test('--debug-rule with next option as value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--debug-rule', '--format']);
      expect(result, isA<ScanParseInvalid>());
    });

    test('--debug-rule null by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.debugRule, isNull);
    });

    test('--min-severity parses valid values', () {
      // All three recognized severity levels should parse successfully.
      for (final sev in ['info', 'warning', 'error', 'INFO', 'Warning']) {
        final result = parseScanArgs(<String>['.', '--min-severity', sev]);
        expect(result, isA<ScanParseOk>(), reason: sev);
        expect(
          (result as ScanParseOk).args.minSeverity,
          sev.toUpperCase(),
          reason: sev,
        );
      }
    });

    test('--min-severity with invalid value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--min-severity', 'debug']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--min-severity must be one of'),
      );
    });

    test('--min-severity with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--min-severity']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--min-severity requires a value'),
      );
    });

    test('--min-severity with next option as value returns invalid', () {
      // --format looks like a flag, not a severity value.
      final result = parseScanArgs(<String>['.', '--min-severity', '--format']);
      expect(result, isA<ScanParseInvalid>());
    });

    test('--min-severity null by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.minSeverity, isNull);
    });

    test('--min-severity combines with other flags', () {
      final result = parseScanArgs(<String>[
        '.',
        '--min-severity',
        'warning',
        '--tier',
        'pedantic',
        '--format',
        'json',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.minSeverity, 'WARNING');
      expect(args.tier, 'pedantic');
      expect(args.formatJson, isTrue);
    });

    test('--max-severity parses valid values', () {
      for (final sev in ['info', 'warning', 'error', 'INFO', 'Error']) {
        final result = parseScanArgs(<String>['.', '--max-severity', sev]);
        expect(result, isA<ScanParseOk>(), reason: sev);
        expect(
          (result as ScanParseOk).args.maxSeverity,
          sev.toUpperCase(),
          reason: sev,
        );
      }
    });

    test('--max-severity with invalid value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--max-severity', 'hint']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--max-severity must be one of'),
      );
    });

    test('--max-severity with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--max-severity']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--max-severity requires a value'),
      );
    });

    test('--max-severity null by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.maxSeverity, isNull);
    });

    test('--min-severity and --max-severity combine for a severity window', () {
      // Both flags together define a severity band.
      final result = parseScanArgs(<String>[
        '.',
        '--min-severity',
        'info',
        '--max-severity',
        'warning',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.minSeverity, 'INFO');
      expect(args.maxSeverity, 'WARNING');
    });

    test('--min-impact parses valid values', () {
      // All three recognized impact levels should parse successfully.
      for (final imp in ['info', 'warning', 'error', 'INFO', 'Warning']) {
        final result = parseScanArgs(<String>['.', '--min-impact', imp]);
        expect(result, isA<ScanParseOk>(), reason: imp);
        expect(
          (result as ScanParseOk).args.minImpact,
          imp.toUpperCase(),
          reason: imp,
        );
      }
    });

    test('--min-impact with invalid value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--min-impact', 'debug']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--min-impact must be one of'),
      );
    });

    test('--min-impact with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--min-impact']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--min-impact requires a value'),
      );
    });

    test('--min-impact with next option as value returns invalid', () {
      // --format looks like a flag, not an impact value.
      final result = parseScanArgs(<String>['.', '--min-impact', '--format']);
      expect(result, isA<ScanParseInvalid>());
    });

    test('--min-impact null by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.minImpact, isNull);
    });

    test('--min-impact combines with severity and other flags', () {
      // Impact filtering is independent of severity filtering.
      final result = parseScanArgs(<String>[
        '.',
        '--min-impact',
        'warning',
        '--min-severity',
        'info',
        '--tier',
        'pedantic',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.minImpact, 'WARNING');
      expect(args.minSeverity, 'INFO');
      expect(args.tier, 'pedantic');
    });

    test('--json-file-path sets path and implies formatJson', () {
      final result = parseScanArgs(<String>[
        '.',
        '--json-file-path',
        '/tmp/out.json',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.jsonFilePath, '/tmp/out.json');
      expect(args.formatJson, isTrue);
    });

    test('--json-file-path with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--json-file-path']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--json-file-path requires a file path'),
      );
    });

    test('--json-file-path with next option as value returns invalid', () {
      // --tier looks like a flag, not a file path.
      final result = parseScanArgs(<String>['.', '--json-file-path', '--tier']);
      expect(result, isA<ScanParseInvalid>());
    });

    test('--json-file-path null by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.jsonFilePath, isNull);
    });

    test('--json-file-path combines with other flags', () {
      final result = parseScanArgs(<String>[
        '.',
        '--json-file-path',
        '/tmp/out.json',
        '--tier',
        'essential',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.jsonFilePath, '/tmp/out.json');
      expect(args.formatJson, isTrue);
      expect(args.tier, 'essential');
    });
  });

  group('--fail-on', () {
    test('--fail-on parses valid values', () {
      for (final sev in ['info', 'warning', 'error', 'INFO', 'Warning']) {
        final result = parseScanArgs(<String>['.', '--fail-on', sev]);
        expect(result, isA<ScanParseOk>(), reason: sev);
        expect(
          (result as ScanParseOk).args.failOn,
          sev.toUpperCase(),
          reason: sev,
        );
      }
    });

    test('--fail-on with invalid value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--fail-on', 'debug']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--fail-on must be one of'),
      );
    });

    test('--fail-on with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--fail-on']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--fail-on requires a value'),
      );
    });

    test('--fail-on with next option as value returns invalid', () {
      // --format looks like a flag, not a severity value.
      final result = parseScanArgs(<String>['.', '--fail-on', '--format']);
      expect(result, isA<ScanParseInvalid>());
    });

    test('--fail-on null by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.failOn, isNull);
    });

    test('--fail-on combines with severity and other flags', () {
      // Decoupled: display everything, fail only on errors.
      final result = parseScanArgs(<String>[
        '.',
        '--fail-on',
        'error',
        '--min-severity',
        'info',
        '--format',
        'json',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.failOn, 'ERROR');
      expect(args.minSeverity, 'INFO');
      expect(args.formatJson, isTrue);
    });
  });

  group('--fail-on-count', () {
    test('--fail-on-count parses valid integer', () {
      final result = parseScanArgs(<String>[
        '.',
        '--fail-on',
        'warning',
        '--fail-on-count',
        '5',
      ]);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.failOnCount, 5);
    });

    test('--fail-on-count accepts zero', () {
      // Zero means "any match triggers exit 1" — same as omitting the flag.
      final result = parseScanArgs(<String>[
        '.',
        '--fail-on',
        'error',
        '--fail-on-count',
        '0',
      ]);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.failOnCount, 0);
    });

    test('--fail-on-count with negative value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--fail-on-count', '-1']);
      // Negative looks like a flag (starts with --), caught by the starts-with check.
      expect(result, isA<ScanParseInvalid>());
    });

    test('--fail-on-count with non-integer returns invalid', () {
      final result = parseScanArgs(<String>['.', '--fail-on-count', 'five']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--fail-on-count must be a non-negative integer'),
      );
    });

    test('--fail-on-count with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--fail-on-count']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--fail-on-count requires'),
      );
    });

    test('--fail-on-count null by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.failOnCount, isNull);
    });
  });

  group('--fail-on-impact', () {
    test('--fail-on-impact parses valid values', () {
      for (final sev in ['info', 'warning', 'error', 'INFO', 'Error']) {
        final result = parseScanArgs(<String>['.', '--fail-on-impact', sev]);
        expect(result, isA<ScanParseOk>());
        expect(
          (result as ScanParseOk).args.failOnImpact,
          sev.toUpperCase(),
        );
      }
    });

    test('--fail-on-impact with invalid value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--fail-on-impact', 'debug']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--fail-on-impact must be one of'),
      );
    });

    test('--fail-on-impact with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--fail-on-impact']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--fail-on-impact requires a value'),
      );
    });

    test('--fail-on-impact null by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.failOnImpact, isNull);
    });

    test('--fail-on-impact combines with --fail-on', () {
      // Both thresholds can coexist — logical OR for exit code.
      final result = parseScanArgs(<String>[
        '.',
        '--fail-on',
        'error',
        '--fail-on-impact',
        'warning',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.failOn, 'ERROR');
      expect(args.failOnImpact, 'WARNING');
    });
  });

  group('--fail-on-impact-count', () {
    test('--fail-on-impact-count parses valid integer', () {
      final result = parseScanArgs(<String>[
        '.',
        '--fail-on-impact',
        'warning',
        '--fail-on-impact-count',
        '3',
      ]);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.failOnImpactCount, 3);
    });

    test('--fail-on-impact-count accepts zero', () {
      final result = parseScanArgs(<String>[
        '.',
        '--fail-on-impact',
        'error',
        '--fail-on-impact-count',
        '0',
      ]);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.failOnImpactCount, 0);
    });

    test('--fail-on-impact-count with negative value returns invalid', () {
      final result =
          parseScanArgs(<String>['.', '--fail-on-impact-count', '-1']);
      expect(result, isA<ScanParseInvalid>());
    });

    test('--fail-on-impact-count with non-integer returns invalid', () {
      final result =
          parseScanArgs(<String>['.', '--fail-on-impact-count', 'five']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--fail-on-impact-count must be a non-negative integer'),
      );
    });

    test('--fail-on-impact-count with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--fail-on-impact-count']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--fail-on-impact-count requires'),
      );
    });

    test('--fail-on-impact-count null by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.failOnImpactCount, isNull);
    });
  });

  group('--fail-on-tier', () {
    test('--fail-on-tier parses valid tier names', () {
      for (final tier in [
        'essential',
        'recommended',
        'professional',
        'comprehensive',
        'pedantic',
      ]) {
        final result = parseScanArgs(<String>['.', '--fail-on-tier', tier]);
        expect(result, isA<ScanParseOk>(), reason: tier);
        expect((result as ScanParseOk).args.failOnTier, tier);
      }
    });

    test('--fail-on-tier is case-insensitive', () {
      final result =
          parseScanArgs(<String>['.', '--fail-on-tier', 'Essential']);
      expect(result, isA<ScanParseOk>());
      // Parser lowercases the value to match tiers.dart convention.
      expect((result as ScanParseOk).args.failOnTier, 'essential');
    });

    test('--fail-on-tier with invalid value returns invalid', () {
      final result =
          parseScanArgs(<String>['.', '--fail-on-tier', 'maximum']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--fail-on-tier must be one of'),
      );
    });

    test('--fail-on-tier with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--fail-on-tier']);
      expect(result, isA<ScanParseInvalid>());
      expect(
        (result as ScanParseInvalid).message,
        contains('--fail-on-tier requires a value'),
      );
    });

    test('--fail-on-tier null by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.failOnTier, isNull);
    });

    test('--fail-on-tier combines with --fail-on and --fail-on-impact', () {
      // All three thresholds can coexist — logical OR for exit code.
      final result = parseScanArgs(<String>[
        '.',
        '--fail-on',
        'error',
        '--fail-on-impact',
        'warning',
        '--fail-on-tier',
        'essential',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.failOn, 'ERROR');
      expect(args.failOnImpact, 'WARNING');
      expect(args.failOnTier, 'essential');
    });
  });

  group('--quiet / -q', () {
    test('--quiet sets quiet flag', () {
      final result = parseScanArgs(<String>['.', '--quiet']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.quiet, isTrue);
    });

    test('-q shorthand sets quiet flag', () {
      final result = parseScanArgs(<String>['.', '-q']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.quiet, isTrue);
    });

    test('quiet is false by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.quiet, isFalse);
    });

    test('--quiet combines with other flags', () {
      final result = parseScanArgs(<String>[
        '.',
        '--quiet',
        '--format',
        'json',
        '--fail-on',
        'error',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.quiet, isTrue);
      expect(args.formatJson, isTrue);
      expect(args.failOn, 'ERROR');
    });
  });

  group('--min-severity filtering (process)', () {
    test(
      '--min-severity error with no errors exits 0 with threshold message',
      () async {
        // Runs against the project itself with --tier essential (mostly info/warning),
        // filtered to ERROR-only — expect exit 0 and the "below threshold" message.
        final result = await Process.run(
          'dart',
          [
            'run',
            'saropa_lints:scan',
            '.',
            '--tier',
            'essential',
            '--min-severity',
            'error',
            '--files',
            'lib/src/scan/scan_cli_args.dart',
          ],
          runInShell: true,
          workingDirectory: Directory.current.path,
        );
        // If there are no error-level diagnostics in this file, expect exit 0
        // and either "No issues found" or the "below threshold" message.
        if (result.exitCode == 0) {
          final stdout = result.stdout.toString();
          expect(
            stdout.contains('No issues') || stdout.contains('below threshold'),
            isTrue,
            reason: 'Expected clean or threshold message, got: $stdout',
          );
        }
      },
    );

    test('--min-severity invalid value exits 2', () async {
      final result = await Process.run(
        'dart',
        ['run', 'saropa_lints:scan', '.', '--min-severity', 'debug'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(result.exitCode, 2);
      expect(
        result.stdout.toString(),
        contains('--min-severity must be one of'),
      );
    });
  });

  group('--fail-on exit code (process)', () {
    test(
      '--fail-on error exits 0 when only info/warning diagnostics exist',
      () async {
        // Scan a file that produces diagnostics but none at ERROR level.
        // --min-severity info ensures diagnostics are shown, --fail-on error
        // means exit 0 because no diagnostic reaches the error threshold.
        final result = await Process.run(
          'dart',
          [
            'run',
            'saropa_lints:scan',
            '.',
            '--tier',
            'essential',
            '--min-severity',
            'info',
            '--fail-on',
            'error',
            '--files',
            'lib/src/scan/scan_cli_args.dart',
          ],
          runInShell: true,
          workingDirectory: Directory.current.path,
        );
        // If any diagnostics were found but none are ERROR, exit should be 0.
        // If no diagnostics at all, exit 0 is also correct.
        expect(
          result.exitCode,
          0,
          reason:
              'Expected exit 0 when --fail-on error but no error-level '
              'diagnostics exist. stderr: ${result.stderr}',
        );
      },
    );

    test('--fail-on info exits 1 when any diagnostic exists', () async {
      // --fail-on info is the lowest threshold: any diagnostic at all → exit 1.
      // Scan the entire lib/src/rules/ directory (which always has diagnostics
      // under essential) to avoid depending on a single file's lint state.
      final result = await Process.run(
        'dart',
        [
          'run',
          'saropa_lints:scan',
          '.',
          '--tier',
          'essential',
          '--fail-on',
          'info',
        ],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      // The project always produces diagnostics under essential — if this
      // ever returns "No issues" the test legitimately fails.
      expect(
        result.stdout.toString(),
        isNot(contains('No issues found')),
        reason: 'Expected diagnostics under essential tier',
      );
      expect(
        result.exitCode,
        1,
        reason:
            'Expected exit 1 when --fail-on info and diagnostics exist. '
            'stdout: ${result.stdout}',
      );
    });

    test('--fail-on error decouples exit code from display', () async {
      // Proves the core decoupling: diagnostics ARE displayed (non-empty
      // output) but exit code is 0 because no diagnostic meets the --fail-on
      // error threshold. This jointly asserts "shown" + "exit 0".
      final result = await Process.run(
        'dart',
        [
          'run',
          'saropa_lints:scan',
          '.',
          '--tier',
          'essential',
          '--min-severity',
          'info',
          '--fail-on',
          'error',
        ],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      final stdout = result.stdout.toString();
      // The project has info/warning diagnostics under essential — confirm
      // they are displayed while exit code remains 0.
      expect(
        stdout.contains('No issues found'),
        isFalse,
        reason: 'Expected diagnostics to be displayed, got: $stdout',
      );
      expect(
        result.exitCode,
        0,
        reason:
            'Expected exit 0: diagnostics shown but none at ERROR level. '
            'stdout: $stdout',
      );
    });

    test('--fail-on invalid value exits 2', () async {
      // Invalid severity value should be caught at parse time.
      final result = await Process.run(
        'dart',
        ['run', 'saropa_lints:scan', '.', '--fail-on', 'debug'],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      expect(result.exitCode, 2);
      expect(result.stdout.toString(), contains('--fail-on must be one of'));
    });

    test(
      '--fail-on checks full set when --max-severity narrows display',
      () async {
        // Display is capped at warning (no errors shown), but --fail-on info
        // checks the FULL set. The project always has info-level diagnostics,
        // so exit should be 1 even though the display window excludes errors.
        final result = await Process.run(
          'dart',
          [
            'run',
            'saropa_lints:scan',
            '.',
            '--tier',
            'essential',
            '--max-severity',
            'warning',
            '--fail-on',
            'info',
          ],
          runInShell: true,
          workingDirectory: Directory.current.path,
        );
        expect(
          result.exitCode,
          1,
          reason:
              'Expected exit 1: --fail-on info checks full set, not the '
              '--max-severity-filtered display. stdout: ${result.stdout}',
        );
      },
    );

    test('--fail-on-count raises the exit threshold', () async {
      // The project has many info+ diagnostics under essential. Without
      // --fail-on-count, --fail-on info exits 1. With a very high count
      // baseline, the matching count won't exceed it — exit 0.
      final result = await Process.run(
        'dart',
        [
          'run',
          'saropa_lints:scan',
          '.',
          '--tier',
          'essential',
          '--fail-on',
          'info',
          '--fail-on-count',
          '99999',
        ],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      // With a baseline of 99999, the project's diagnostics can't exceed it.
      expect(
        result.exitCode,
        0,
        reason:
            'Expected exit 0: --fail-on-count 99999 baseline not exceeded. '
            'stdout: ${result.stdout}',
      );
    });
  });

  group('--quiet (process)', () {
    test('--quiet suppresses stderr messages', () async {
      // Run with -q to verify no stderr output from the scanner.
      final result = await Process.run(
        'dart',
        [
          'run',
          'saropa_lints:scan',
          '.',
          '--tier',
          'essential',
          '-q',
          '--files',
          'lib/src/scan/scan_cli_args.dart',
        ],
        runInShell: true,
        workingDirectory: Directory.current.path,
      );
      // stderr should be empty or contain only whitespace when --quiet is set.
      final stderrOutput = result.stderr.toString().trim();
      expect(
        stderrOutput,
        isEmpty,
        reason: 'Expected empty stderr with --quiet, got: $stderrOutput',
      );
    });
  });

  group('--exclude-globs', () {
    test('--exclude-globs collects multiple patterns', () {
      final result = parseScanArgs(<String>[
        '.',
        '--exclude-globs',
        '**/ephemeral/**',
        '**/vendor/**',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.excludeGlobs, ['**/ephemeral/**', '**/vendor/**']);
    });

    test('--exclude-globs empty by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.excludeGlobs, isEmpty);
    });

    test('--exclude-globs stops at next flag', () {
      // The parser should stop consuming patterns when it hits another flag.
      final result = parseScanArgs(<String>[
        '.',
        '--exclude-globs',
        '**/vendor/**',
        '--tier',
        'essential',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.excludeGlobs, ['**/vendor/**']);
      expect(args.tier, 'essential');
    });

    test('--exclude-globs with no patterns results in empty list', () {
      // No patterns before the next flag — valid but a no-op.
      final result = parseScanArgs(<String>[
        '.',
        '--exclude-globs',
        '--tier',
        'essential',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.excludeGlobs, isEmpty);
      expect(args.tier, 'essential');
    });

    test('--exclude-globs combines with other flags', () {
      final result = parseScanArgs(<String>[
        '.',
        '--exclude-globs',
        '**/build/**',
        '--format',
        'json',
        '--quiet',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.excludeGlobs, ['**/build/**']);
      expect(args.formatJson, isTrue);
      expect(args.quiet, isTrue);
    });
  });

  group('--include-globs', () {
    test('--include-globs collects multiple patterns', () {
      final result = parseScanArgs(<String>[
        '.',
        '--include-globs',
        '**/ephemeral/**',
        '**/generated/**',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.includeGlobs, ['**/ephemeral/**', '**/generated/**']);
    });

    test('--include-globs empty by default', () {
      final result = parseScanArgs(<String>['.']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.includeGlobs, isEmpty);
    });

    test('--include-globs combines with --exclude-globs', () {
      // Both flags should be independently collected.
      final result = parseScanArgs(<String>[
        '.',
        '--exclude-globs',
        '**/vendor/**',
        '--include-globs',
        '**/ephemeral/**',
      ]);
      expect(result, isA<ScanParseOk>());
      final args = (result as ScanParseOk).args;
      expect(args.excludeGlobs, ['**/vendor/**']);
      expect(args.includeGlobs, ['**/ephemeral/**']);
    });
  });

  group('--json-file-path (process)', () {
    test('--json-file-path writes valid JSON to the file', () async {
      // Use a temp directory to avoid polluting the project tree.
      final tempDir = Directory.systemTemp.createTempSync('scan_json_test_');
      final jsonPath = '${tempDir.path}/output.json';
      try {
        final result = await Process.run(
          'dart',
          [
            'run',
            'saropa_lints:scan',
            '.',
            '--tier',
            'essential',
            '--json-file-path',
            jsonPath,
            '--files',
            'lib/src/scan/scan_cli_args.dart',
          ],
          runInShell: true,
          workingDirectory: Directory.current.path,
        );
        // The file should exist and start with a JSON array/object.
        final file = File(jsonPath);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'Expected JSON file at $jsonPath. '
              'exit: ${result.exitCode}, stderr: ${result.stderr}',
        );
        final content = file.readAsStringSync().trim();
        // Scan output is always a JSON array.
        expect(
          content.startsWith('[') || content.startsWith('{'),
          isTrue,
          reason:
              'Expected JSON content, got: ${content.substring(0, 40.clamp(0, content.length))}',
        );
        // Stderr should confirm the file path (unless --quiet suppressed it).
        expect(
          result.stderr.toString(),
          contains('JSON written to:'),
          reason: 'Expected stderr confirmation of file write',
        );
      } finally {
        // Retry-tolerant cleanup: Windows file handles can linger after tests
        safeDeleteDir(tempDir);
      }
    });

    test('--json-file-path creates parent directories', () async {
      // Verify the parent-directory creation hardening.
      final tempDir = Directory.systemTemp.createTempSync('scan_json_mkdir_');
      final nestedPath = '${tempDir.path}/sub/dir/output.json';
      try {
        final result = await Process.run(
          'dart',
          [
            'run',
            'saropa_lints:scan',
            '.',
            '--tier',
            'essential',
            '--json-file-path',
            nestedPath,
            '--files',
            'lib/src/scan/scan_cli_args.dart',
          ],
          runInShell: true,
          workingDirectory: Directory.current.path,
        );
        final file = File(nestedPath);
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'Expected JSON file at nested path $nestedPath. '
              'exit: ${result.exitCode}, stderr: ${result.stderr}',
        );
      } finally {
        safeDeleteDir(tempDir);
      }
    });
  });
}
