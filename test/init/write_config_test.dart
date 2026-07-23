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
      avoid_unguarded_debug: true
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
      avoid_unguarded_debug: true
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

    // The headless path the VS Code extension and CI use must apply the same
    // beta/deprecated lifecycle filter the interactive init does — without it a
    // beta rule sitting in a tier would be enabled in extension-written configs
    // while init excluded it (the divergence this filter closes). Enabled rules
    // are emitted as `rule: true`, so the beta rule's absence proves the filter.
    test('excludes beta/deprecated rules from the generated tier set', () {
      final dir = Directory.systemTemp.createTempSync('write_config_test');
      try {
        final result = runWriteConfig(
          WriteConfigOptions(targetDir: dir.path, tier: 'essential'),
        );
        expect(result.ok, isTrue);
        final content = File(
          '${dir.path}${Platform.pathSeparator}analysis_options.yaml',
        ).readAsStringSync();

        // avoid_api_key_in_code is an essential-tier rule marked RuleStatus.beta.
        expect(content.contains('avoid_api_key_in_code: true'), isFalse);
        // Essential output is non-empty (the filter did not wipe the tier).
        expect(content.contains('diagnostics:'), isTrue);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    // The filter is a default, not a hard ban: a user who explicitly enables a
    // beta rule via RULE OVERRIDES keeps it. Two-pass so the override lands in a
    // canonical (already-migrated) custom file the second run will not rewrite.
    test('honors an explicit override re-enabling a beta rule', () {
      final dir = Directory.systemTemp.createTempSync('write_config_test');
      try {
        final opts = WriteConfigOptions(targetDir: dir.path, tier: 'essential');
        // First pass creates the canonical analysis_options_custom.yaml.
        expect(runWriteConfig(opts).ok, isTrue);
        final customFile = File(
          '${dir.path}${Platform.pathSeparator}analysis_options_custom.yaml',
        );
        // Append an explicit enable override (extractOverridesFromFile matches a
        // `rule: true` line anywhere in the file).
        customFile.writeAsStringSync(
          '${customFile.readAsStringSync()}\n    avoid_api_key_in_code: true\n',
        );
        // Second pass must re-enable the opted-in beta rule.
        expect(runWriteConfig(opts).ok, isTrue);
        final content = File(
          '${dir.path}${Platform.pathSeparator}analysis_options.yaml',
        ).readAsStringSync();
        expect(content.contains('avoid_api_key_in_code: true'), isTrue);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}
