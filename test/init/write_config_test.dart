import 'dart:io';

import 'package:saropa_lints/src/init/write_config_runner.dart';
import 'package:test/test.dart';

/// Unit tests for headless config writer (write_config).
void main() {
  group('runWriteConfig', () {
    test('invalid tier returns error', () {
      final dir = Directory.systemTemp.createTempSync('write_config_test');
      try {
        final result = runWriteConfig(
          WriteConfigOptions(targetDir: dir.path, tier: 'invalid_tier'),
        );
        expect(result.ok, isFalse);
        expect(result.error, contains('Invalid tier'));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('valid tier writes analysis_options.yaml with plugins section', () {
      final dir = Directory.systemTemp.createTempSync('write_config_test');
      try {
        final result = runWriteConfig(
          WriteConfigOptions(targetDir: dir.path, tier: 'recommended'),
        );
        expect(result.ok, isTrue);
        final outputFile = File(
          '${dir.path}${Platform.pathSeparator}analysis_options.yaml',
        );
        expect(outputFile.existsSync(), isTrue);
        final content = outputFile.readAsStringSync();
        expect(content, contains('plugins:'));
        expect(content, contains('saropa_lints:'));
        expect(content, contains('diagnostics:'));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('creates analysis_options_custom.yaml when missing', () {
      final dir = Directory.systemTemp.createTempSync('write_config_test');
      try {
        final result = runWriteConfig(
          WriteConfigOptions(targetDir: dir.path, tier: 'essential'),
        );
        expect(result.ok, isTrue);
        final customFile = File(
          '${dir.path}${Platform.pathSeparator}analysis_options_custom.yaml',
        );
        expect(customFile.existsSync(), isTrue);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}
