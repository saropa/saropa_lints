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

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart' show SaropaLintRule;
import 'package:saropa_lints/src/native/config_loader.dart'
    show loadNativePluginConfigFromProjectRoot;
import 'package:test/test.dart';

void main() {
  Set<String>? savedEnabled;
  Set<String>? savedDisabled;

  setUp(() {
    savedEnabled = SaropaLintRule.enabledRules;
    savedDisabled = SaropaLintRule.disabledRules;
    // Reset to null so we can verify the loader actually populated them.
    SaropaLintRule.enabledRules = null;
    SaropaLintRule.disabledRules = null;
  });

  tearDown(() {
    SaropaLintRule.enabledRules = savedEnabled;
    SaropaLintRule.disabledRules = savedDisabled;
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
      avoid_debug_print: true
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
            'avoid_debug_print',
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
        tempDir.deleteSync(recursive: true);
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
        File(p.join(tempDir.path, 'analysis_options.yaml')).writeAsStringSync(
          'analyzer:\n  exclude:\n    - "**/*.g.dart"\n',
        );

        loadNativePluginConfigFromProjectRoot(tempDir.path);

        expect(
          SaropaLintRule.enabledRules,
          isNull,
          reason: 'Missing diagnostics block must fail closed, not open',
        );
      } finally {
        tempDir.deleteSync(recursive: true);
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
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
