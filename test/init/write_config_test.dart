/// Unit tests for [runWriteConfig]: tier validation, emitted YAML shape, legacy pack migration.
///
/// Each case uses a fresh temp directory; `finally` blocks remove it after assertions.
import 'dart:io';

import 'package:saropa_lints/src/config/analysis_options_rule_packs.dart';
import 'package:saropa_lints/src/init/write_config_runner.dart';
import 'package:test/test.dart';

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

    test(
      'normalizes legacy migration_packs to canonical rule_packs on write',
      () {
        final dir = Directory.systemTemp.createTempSync('write_config_test');
        try {
          final outputFile = File(
            '${dir.path}${Platform.pathSeparator}analysis_options.yaml',
          );
          outputFile.writeAsStringSync('''
plugins:
  saropa_lints:
    version: "9.0.0"
    migration_packs:
      enabled:
        - drift
    diagnostics:
      avoid_debug_print: true
''');

          final result = runWriteConfig(
            WriteConfigOptions(targetDir: dir.path, tier: 'recommended'),
          );
          expect(result.ok, isTrue);

          final content = outputFile.readAsStringSync();
          expect(content.contains('migration_packs:'), isFalse);
          expect(content.contains('rule_packs:'), isTrue);
          expect(parseRulePacksEnabledList(content), contains('drift'));
        } finally {
          dir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'read-write-read flow preserves packs after legacy migration_packs normalization',
      () {
        final dir = Directory.systemTemp.createTempSync('write_config_test');
        try {
          final outputFile = File(
            '${dir.path}${Platform.pathSeparator}analysis_options.yaml',
          );
          outputFile.writeAsStringSync('''
plugins:
  saropa_lints:
    version: "9.0.0"
    migration_packs:
      enabled:
        # legacy key with mixed formatting
        - "riverpod"
        - drift # db
    diagnostics:
      avoid_debug_print: true
''');

          final before = outputFile.readAsStringSync();
          expect(parseRulePacksEnabledList(before), ['riverpod', 'drift']);

          final result = runWriteConfig(
            WriteConfigOptions(targetDir: dir.path, tier: 'recommended'),
          );
          expect(result.ok, isTrue);

          final after = outputFile.readAsStringSync();
          expect(after.contains('migration_packs:'), isFalse);
          expect(after.contains('rule_packs:'), isTrue);
          expect(parseRulePacksEnabledList(after), ['drift', 'riverpod']);
        } finally {
          dir.deleteSync(recursive: true);
        }
      },
    );
  });
}
