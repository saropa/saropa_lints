/// Unit tests for [runWriteConfig]: tier validation, emitted YAML shape, legacy pack migration.
///
/// Each case uses a fresh temp directory; `finally` blocks remove it after assertions.
library;

import 'dart:io';

import 'package:saropa_lints/src/config/analysis_options_rule_packs.dart';
import 'package:saropa_lints/src/init/write_config_runner.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

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
        // Retry-tolerant cleanup: Windows file handles can linger after tests
        safeDeleteDir(dir);
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
        expect(content, contains('log_level: info'));
      } finally {
        safeDeleteDir(dir);
      }
    });

    // Lane 2 part B (plans/PLAN_scan_only_diagnostics.md): the in-process
    // plugin costs several GB on large projects, so a brand-new project must
    // not get a live `plugins:` block by default — the block is written
    // commented out behind the same sentinels the extension's "Lint
    // integration: Off" toggle uses.
    test('new project writes plugins block commented out by default', () {
      final dir = Directory.systemTemp.createTempSync('write_config_test');
      try {
        final result = runWriteConfig(
          WriteConfigOptions(targetDir: dir.path, tier: 'recommended'),
        );
        expect(result.ok, isTrue);
        final content = File(
          '${dir.path}${Platform.pathSeparator}analysis_options.yaml',
        ).readAsStringSync();

        expect(
          content,
          contains(
            'saropa_lints integration turned OFF by the VS Code extension',
          ),
        );
        expect(content, contains('# <<< saropa_lints end of disabled'));
        // The live header line must itself be commented — not just present
        // somewhere in the file — proving the analyzer will not load it.
        expect(content, isNot(contains('\nplugins:\n')));
        expect(content, contains('# plugins:'));
      } finally {
        safeDeleteDir(dir);
      }
    });

    // A project that already has a LIVE plugins: block (from before this
    // default changed, or from a user who deliberately re-enabled it) must
    // not be silently flipped off by an unrelated tier change.
    test('existing live plugins block stays live after a tier change', () {
      final dir = Directory.systemTemp.createTempSync('write_config_test');
      try {
        final outputFile = File(
          '${dir.path}${Platform.pathSeparator}analysis_options.yaml',
        );
        outputFile.writeAsStringSync('''
plugins:
  saropa_lints:
    version: "9.0.0"
    diagnostics:
      avoid_unguarded_debug: true
''');

        final result = runWriteConfig(
          WriteConfigOptions(targetDir: dir.path, tier: 'professional'),
        );
        expect(result.ok, isTrue);

        final content = outputFile.readAsStringSync();
        expect(content, isNot(contains('turned OFF by the VS Code')));
        expect(content, isNot(contains('# plugins:')));
        expect(content.trimLeft(), startsWith('plugins:\n'));
      } finally {
        safeDeleteDir(dir);
      }
    });

    // A project where integration was explicitly turned off (sentinel
    // present) must stay off through a regenerate — turning saropaLints.
    // enabled back on must not silently restore the heavy in-process plugin.
    test(
      'existing disabled plugins block stays disabled after a tier change',
      () {
        final dir = Directory.systemTemp.createTempSync('write_config_test');
        try {
          final outputFile = File(
            '${dir.path}${Platform.pathSeparator}analysis_options.yaml',
          );
          outputFile.writeAsStringSync('''
# >>> saropa_lints integration turned OFF by the VS Code extension — toggle "Lint integration" On to restore >>>
# plugins:
#   saropa_lints:
#     version: "9.0.0"
#     diagnostics:
#       avoid_unguarded_debug: true
# <<< saropa_lints end of disabled integration block <<<
''');

          final result = runWriteConfig(
            WriteConfigOptions(targetDir: dir.path, tier: 'professional'),
          );
          expect(result.ok, isTrue);

          final content = outputFile.readAsStringSync();
          expect(
            content,
            contains(
              'saropa_lints integration turned OFF by the VS Code extension',
            ),
          );
          expect(content, isNot(contains('\nplugins:\n')));
        } finally {
          safeDeleteDir(dir);
        }
      },
    );

    // A disabled block's `rule_name: true` lines are what config_loader.dart
    // parses back into SaropaLintRule.enabledRules on restore — dropping any
    // of them would silently downgrade a restored project to the essential-
    // tier fallback. Only the surrounding prose/box-art is safe to compact.
    test(
      'new (disabled-by-default) project keeps every enabled rule line but drops per-rule comments',
      () {
        final dir = Directory.systemTemp.createTempSync('write_config_test');
        try {
          final result = runWriteConfig(
            WriteConfigOptions(targetDir: dir.path, tier: 'essential'),
          );
          expect(result.ok, isTrue);
          final content = File(
            '${dir.path}${Platform.pathSeparator}analysis_options.yaml',
          ).readAsStringSync();

          // Compact mode still emits every rule as its own diagnostics entry...
          expect(content, contains(': true'));
          // ...but never the long inline problem-message comment that made
          // disabled blocks balloon to hundreds of extra lines of dead prose.
          expect(content, isNot(contains('[WARNING]')));
          expect(content, isNot(contains('[INFO]')));
          expect(content, isNot(contains('═')));
          expect(content, isNot(contains('┌')));
        } finally {
          safeDeleteDir(dir);
        }
      },
    );

    // A live block is actively read/edited by a human, so it keeps the full
    // verbose form — only the (unread, commented-out) disabled case compacts.
    test('existing live plugins block keeps verbose per-rule comments', () {
      final dir = Directory.systemTemp.createTempSync('write_config_test');
      try {
        final outputFile = File(
          '${dir.path}${Platform.pathSeparator}analysis_options.yaml',
        );
        outputFile.writeAsStringSync('''
plugins:
  saropa_lints:
    version: "9.0.0"
    diagnostics:
      avoid_unguarded_debug: true
''');

        final result = runWriteConfig(
          WriteConfigOptions(targetDir: dir.path, tier: 'essential'),
        );
        expect(result.ok, isTrue);

        final content = outputFile.readAsStringSync();
        expect(content, contains('SAROPA LINTS CONFIGURATION'));
      } finally {
        safeDeleteDir(dir);
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
        safeDeleteDir(dir);
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
          safeDeleteDir(dir);
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
          safeDeleteDir(dir);
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
        safeDeleteDir(dir);
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
        safeDeleteDir(dir);
      }
    });
  });
}
