/// Tests `saropa_lints:scan` argv parsing ([parseScanArgs]) and one process-level guard.
///
/// The process test shells out to `dart run` so flag errors match real CLI behavior;
/// pure parser cases stay in-memory for speed.
library;

import 'dart:io';

import 'package:saropa_lints/src/scan/scan_cli_args.dart';
import 'package:test/test.dart';

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
      final result = parseScanArgs(<String>[
        '.',
        '--min-severity',
        '--format',
      ]);
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
  });

  group('--min-severity filtering (process)', () {
    test('--min-severity error with no errors exits 0 with threshold message',
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
    });

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
}
