// Tests the fix for the analyzer-launched-plugin silent-failure bug.
//
// Background: `analysis_server_plugin` calls `Plugin.register` synchronously
// in the `PluginServer` constructor, before `start()`, before the channel,
// before any context-root info. The plugin's `start()` then calls
// `loadNativePluginConfig()` which reads `analysis_options.yaml` relative
// to `Directory.current.path`. When the analyzer launches the plugin, cwd
// is the analysis-server process's cwd (often the user's home, or wherever
// VS Code was launched from) — NOT the consumer project root. The file
// read returns null, `enabledRules` stays null, and every rule was
// gated off at register time (the old kill-switch).
//
// Fix: `loadNativePluginConfigFromProjectRoot(projectRoot)` reads the
// config from a known project root (derived at visitor-entry time from
// the analyzed file path by walking up to the nearest `pubspec.yaml`).
// This test exercises that path.

/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `config_loader_project_root_test` (config loader project root).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart' show SaropaLintRule;
import 'package:saropa_lints/src/native/config_loader.dart'
    show
        loadNativePluginConfigFromProjectRoot,
        loadRulePacksConfigFromProjectRoot;
import 'package:saropa_lints/src/native/plugin_logger.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  Set<String>? savedEnabled;
  Set<String>? savedDisabled;

  late PluginLogLevel savedLogLevel;

  setUp(() {
    savedEnabled = SaropaLintRule.enabledRules;
    savedDisabled = SaropaLintRule.disabledRules;
    savedLogLevel = PluginLogger.minLevel;
    // Reset to null so we can verify the loader actually populated them.
    SaropaLintRule.enabledRules = null;
    SaropaLintRule.disabledRules = null;
    PluginLogger.resetForTesting();
  });

  tearDown(() {
    SaropaLintRule.enabledRules = savedEnabled;
    SaropaLintRule.disabledRules = savedDisabled;
    PluginLogger.minLevel = savedLogLevel;
    PluginLogger.resetForTesting();
  });

  group('loadNativePluginConfigFromProjectRoot', () {
    test('populates enabledRules from analysis_options.yaml at given root', () {
      // Arrange: create a temp dir with the canonical config format the
      // init tool generates (`plugins > saropa_lints > diagnostics:`).
      final tempDir = Directory.systemTemp.createTempSync('saropa_lints_root_');
      try {
        File(p.join(tempDir.path, 'analysis_options.yaml')).writeAsStringSync(
          '''
plugins:
  saropa_lints:
    version: "12.2.1"
    diagnostics:
      avoid_unguarded_debug: true
      avoid_hardcoded_credentials: true
      prefer_const_constructors: false
''',
        );

        // Act: load from that directory (simulates the visitor-entry-time
        // lazy reload once a file path reveals the real project root).
        loadNativePluginConfigFromProjectRoot(tempDir.path);

        // Assert: enabledRules now contains the `true` entries and
        // disabledRules contains the `false` entry. This is the proof
        // that diagnostics will actually flow at visit time.
        expect(SaropaLintRule.enabledRules, isNotNull);
        expect(
          SaropaLintRule.enabledRules,
          containsAll(<String>[
            'avoid_unguarded_debug',
            'avoid_hardcoded_credentials',
          ]),
        );
        expect(
          SaropaLintRule.enabledRules!.contains('prefer_const_constructors'),
          isFalse,
          reason: '`false` entries must not appear in enabledRules',
        );
        expect(
          SaropaLintRule.disabledRules,
          contains('prefer_const_constructors'),
        );
      } finally {
        // Retry-tolerant cleanup: Windows file handles can linger after tests
        safeDeleteDir(tempDir);
      }
    });

    test('silently returns when projectRoot is empty (no crash)', () {
      loadNativePluginConfigFromProjectRoot('');
      // No assertion: the contract is "never throws". Reaching this
      // line without an exception is the test.
      expect(SaropaLintRule.enabledRules, isNull);
    });

    test('no enables when analysis_options.yaml has no diagnostics block', () {
      final tempDir = Directory.systemTemp.createTempSync('saropa_lints_root_');
      try {
        // analysis_options.yaml exists but is missing the
        // `plugins > saropa_lints > diagnostics:` block. The loader
        // must surface this via developer.log (not tested here — runtime
        // side-effect) and leave enabledRules null so the visitor-entry
        // gate fails closed.
        File(
          p.join(tempDir.path, 'analysis_options.yaml'),
        ).writeAsStringSync('analyzer:\n  exclude:\n    - "**/*.g.dart"\n');

        loadNativePluginConfigFromProjectRoot(tempDir.path);

        expect(
          SaropaLintRule.enabledRules,
          isNull,
          reason: 'Missing diagnostics block must fail closed, not open',
        );
      } finally {
        safeDeleteDir(tempDir);
      }
    });

    test('log_level is honored from custom config file', () {
      // log_level lives in analysis_options_custom.yaml (top-level key) to
      // avoid unsupported_option warnings from the SDK's plugin-block validator.
      final tempDir = Directory.systemTemp.createTempSync('saropa_lints_root_');
      try {
        File(p.join(tempDir.path, 'analysis_options.yaml')).writeAsStringSync(
          '''
plugins:
  saropa_lints:
    version: "14.3.8"
''',
        );
        File(
          p.join(tempDir.path, 'analysis_options_custom.yaml'),
        ).writeAsStringSync('log_level: debug\n');

        loadNativePluginConfigFromProjectRoot(tempDir.path);

        expect(
          PluginLogger.minLevel,
          PluginLogLevel.debug,
          reason: 'log_level must be parsed from custom config file',
        );
      } finally {
        safeDeleteDir(tempDir);
      }
    });

    test('unrecognized log_level logs a warning and keeps default', () {
      final tempDir = Directory.systemTemp.createTempSync('saropa_lints_root_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        // log_level is read from the custom file; diagnostics from the main file.
        File(p.join(tempDir.path, 'analysis_options.yaml')).writeAsStringSync(
          '''
plugins:
  saropa_lints:
    version: "14.3.8"
    diagnostics:
      avoid_hardcoded_credentials: true
''',
        );
        File(
          p.join(tempDir.path, 'analysis_options_custom.yaml'),
        ).writeAsStringSync('log_level: verbose\n');

        PluginLogger.setProjectRoot(tempDir.path);
        loadNativePluginConfigFromProjectRoot(tempDir.path);

        expect(
          PluginLogger.minLevel,
          PluginLogLevel.info,
          reason: 'Unrecognized value must not change the default',
        );

        final logFile = File(PluginLogger.logFilePathForTesting!);
        final contents = logFile.readAsStringSync();
        expect(
          contents,
          contains('Unrecognized log_level "verbose"'),
          reason: 'Must warn about the bad value',
        );
        expect(
          contents,
          contains('Keeping current level (info)'),
          reason: 'Must state the retained level, not hardcode "falling back"',
        );
      } finally {
        safeDeleteDir(tempDir);
      }
    });

    test('log_level is parsed from custom config file', () {
      // log_level is a top-level key in the custom file — no nesting, so
      // indentation does not matter. This test verifies the basic read path.
      final tempDir = Directory.systemTemp.createTempSync('saropa_lints_root_');
      try {
        File(
          p.join(tempDir.path, 'analysis_options_custom.yaml'),
        ).writeAsStringSync('log_level: error\n');

        loadNativePluginConfigFromProjectRoot(tempDir.path);

        expect(
          PluginLogger.minLevel,
          PluginLogLevel.error,
          reason: 'log_level must be parsed from custom config',
        );
      } finally {
        safeDeleteDir(tempDir);
      }
    });

    test('log_level falls back to plugin block with deprecation warning', () {
      // Deprecation path: log_level still in the old `plugins > saropa_lints:`
      // block and no custom file. The loader must use the old value but emit
      // a migration warning.
      final tempDir = Directory.systemTemp.createTempSync('saropa_lints_root_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        File(p.join(tempDir.path, 'analysis_options.yaml')).writeAsStringSync(
          '''
plugins:
  saropa_lints:
    version: "15.2.4"
    log_level: debug
    diagnostics:
      avoid_hardcoded_credentials: true
''',
        );
        // No custom file — forces the fallback path.

        PluginLogger.setProjectRoot(tempDir.path);
        loadNativePluginConfigFromProjectRoot(tempDir.path);

        // The old value must still be honored via the fallback.
        expect(
          PluginLogger.minLevel,
          PluginLogLevel.debug,
          reason: 'log_level from old location must be honored as fallback',
        );

        // A deprecation warning must be logged pointing at the new location.
        final logFile = File(PluginLogger.logFilePathForTesting!);
        final contents = logFile.readAsStringSync();
        expect(
          contents,
          contains('move it to analysis_options_custom.yaml'),
          reason: 'Must warn to migrate log_level to the custom file',
        );
      } finally {
        safeDeleteDir(tempDir);
      }
    });

    test('no enables when analysis_options.yaml does not exist', () {
      final tempDir = Directory.systemTemp.createTempSync('saropa_lints_root_');
      try {
        // Empty directory — no analysis_options.yaml at all.
        loadNativePluginConfigFromProjectRoot(tempDir.path);

        expect(
          SaropaLintRule.enabledRules,
          isNull,
          reason: 'Missing config file must fail closed, not open',
        );
      } finally {
        safeDeleteDir(tempDir);
      }
    });
  });

  group('loadRulePacksConfigFromProjectRoot', () {
    test('re-merges using analyzed project root in multi-root layouts', () {
      final tempDir = Directory.systemTemp.createTempSync(
        'saropa_lints_multi_',
      );
      try {
        final repoRoot = Directory(p.join(tempDir.path, 'repo'))..createSync();
        final appA = Directory(p.join(repoRoot.path, 'apps', 'a'))
          ..createSync(recursive: true);
        final appB = Directory(p.join(repoRoot.path, 'apps', 'b'))
          ..createSync(recursive: true);

        File(p.join(appA.path, 'analysis_options.yaml')).writeAsStringSync('''
plugins:
  saropa_lints:
    rule_packs:
      enabled:
        - riverpod
''');
        File(p.join(appB.path, 'analysis_options.yaml')).writeAsStringSync('''
plugins:
  saropa_lints:
    rule_packs:
      enabled:
        - drift
''');

        // loadRulePacksConfigFromProjectRoot reads config from the passed
        // root only — do not mutate Directory.current (parallel tests use
        // cwd-relative paths such as example/ fixtures).
        SaropaLintRule.enabledRules = null;
        SaropaLintRule.disabledRules = null;

        loadRulePacksConfigFromProjectRoot(appA.path);
        expect(
          SaropaLintRule.enabledRules,
          contains('require_provider_scope'),
          reason: 'Expected app A riverpod pack from its project root',
        );
        expect(
          SaropaLintRule.enabledRules!.contains('require_drift_database_close'),
          isFalse,
          reason: 'Drift rules from app B must not leak into app A config',
        );

        loadRulePacksConfigFromProjectRoot(appB.path);
        expect(
          SaropaLintRule.enabledRules,
          contains('require_drift_database_close'),
          reason: 'Expected app B drift pack from its project root',
        );
        expect(
          SaropaLintRule.enabledRules!.contains('require_provider_scope'),
          isFalse,
          reason: 'Prior pack contributions must be removed on root switch',
        );
      } finally {
        safeDeleteDir(tempDir);
      }
    });
  });
}
