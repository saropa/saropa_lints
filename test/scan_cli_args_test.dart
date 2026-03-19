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
      expect(result.exitCode, 2, reason: 'Expected exit 2 when --tier has no value');
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
      final result = parseScanArgs(<String>['.', '--files', 'lib/a.dart', 'lib/b.dart', '--tier', 'recommended']);
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.dartFiles, ['lib/a.dart', 'lib/b.dart']);
      expect((result).args.tier, 'recommended');
    });

    test('--files-from-stdin uses stdinLines when provided', () {
      final result = parseScanArgs(
        <String>['.', '--files-from-stdin'],
        stdinLines: ['lib/foo.dart', 'lib/bar.dart'],
      );
      expect(result, isA<ScanParseOk>());
      expect((result as ScanParseOk).args.dartFiles, ['lib/foo.dart', 'lib/bar.dart']);
    });

    test('--tier with value parses', () {
      for (final tier in ['essential', 'recommended', 'professional', 'comprehensive', 'pedantic']) {
        final result = parseScanArgs(<String>['.', '--tier', tier]);
        expect(result, isA<ScanParseOk>(), reason: tier);
        expect((result as ScanParseOk).args.tier, tier);
      }
    });

    test('--tier with no value returns invalid', () {
      final result = parseScanArgs(<String>['.', '--tier']);
      expect(result, isA<ScanParseInvalid>());
      expect((result as ScanParseInvalid).message, contains('--tier requires a value'));
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
  });
}
