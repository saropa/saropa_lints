// Tests the "off means off" kill switch in the native plugin config loader.
//
// Background (2026-08-13/14 field incident, contacts project): the VS Code
// extension's "Lint integration" toggle comments out the `plugins:` block in
// analysis_options.yaml and brackets it with a sentinel marker. Despite that,
// a plugin session was observed loading 1034 rules from config fallbacks
// (tier floor / severity-implied / packs) and holding multi-GB of resolved
// AST state in the analysis server. The fix: when the in-server plugin
// ([markNativePluginStarted]) loads config from a root whose
// analysis_options.yaml contains the sentinel, it enables ZERO rules.
//
// Runs in its own file (own test isolate) because [markNativePluginStarted]
// arms a process-global latch with no reset — sharing a file with tests that
// rely on scan-CLI/full-coverage semantics would poison them.

/// Analyzer-config tests for the lint-integration OFF sentinel kill switch.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart' show SaropaLintRule;
import 'package:saropa_lints/src/native/config_loader.dart'
    show
        kIntegrationOffSentinel,
        loadNativePluginConfigFromProjectRoot,
        markNativePluginStarted;
import 'package:saropa_lints/src/native/plugin_logger.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  Set<String>? savedEnabled;
  Set<String>? savedDisabled;

  setUp(() {
    savedEnabled = SaropaLintRule.enabledRules;
    savedDisabled = SaropaLintRule.disabledRules;
    SaropaLintRule.enabledRules = null;
    SaropaLintRule.disabledRules = null;
    PluginLogger.resetForTesting();
  });

  tearDown(() {
    SaropaLintRule.enabledRules = savedEnabled;
    SaropaLintRule.disabledRules = savedDisabled;
    PluginLogger.resetForTesting();
  });

  test('in-server plugin enables ZERO rules when the OFF sentinel is present, '
      'even with severity-implied and diagnostics fallbacks available', () {
    final tempDir = Directory.systemTemp.createTempSync('saropa_off_');
    try {
      // The exact shape runDisable() leaves behind: sentinel + commented
      // block. Also include a live diagnostics-style leftover elsewhere to
      // prove the sentinel wins over anything else in the file.
      File(p.join(tempDir.path, 'analysis_options.yaml')).writeAsStringSync('''
analyzer:
  errors:
    todo: ignore

# >>> $kIntegrationOffSentinel — toggle "Lint integration" On to restore >>>
# plugins:
#   saropa_lints:
#     version: "14.5.5"
#     diagnostics:
#       avoid_unguarded_debug: true
# <<< saropa_lints end of disabled integration block <<<
''');
      // Severity overrides in the custom yaml implicitly enable rules —
      // the sentinel must beat this fallback too (it survived the yaml
      // toggle in the field because the extension never touches this file).
      File(
        p.join(tempDir.path, 'analysis_options_custom.yaml'),
      ).writeAsStringSync('''
severity_overrides:
  avoid_hardcoded_credentials: ERROR
''');

      markNativePluginStarted();
      loadNativePluginConfigFromProjectRoot(tempDir.path);

      expect(
        SaropaLintRule.enabledRules,
        isNull,
        reason:
            'OFF sentinel present: the in-server plugin must enable no '
            'rules regardless of fallback config sources.',
      );
    } finally {
      // Retry-tolerant cleanup: Windows file handles can linger after tests
      safeDeleteDir(tempDir);
    }
  });

  test(
    'sentinel absent: plugin load path still populates from diagnostics',
    () {
      final tempDir = Directory.systemTemp.createTempSync('saropa_on_');
      try {
        File(p.join(tempDir.path, 'analysis_options.yaml')).writeAsStringSync(
          '''
plugins:
  saropa_lints:
    version: "14.5.8"
    diagnostics:
      avoid_unguarded_debug: true
''',
        );

        markNativePluginStarted();
        loadNativePluginConfigFromProjectRoot(tempDir.path);

        expect(
          SaropaLintRule.enabledRules,
          contains('avoid_unguarded_debug'),
          reason: 'Without the sentinel, explicit enables must still load.',
        );
      } finally {
        safeDeleteDir(tempDir);
      }
    },
  );
}
