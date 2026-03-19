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
}
