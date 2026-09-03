/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `analysis_options_rule_packs_test` (analysis options rule packs).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
library;

import 'package:saropa_lints/src/config/analysis_options_rule_packs.dart';
import 'package:test/test.dart';

// analysis_options rule_packs enabled list parsing and serialization.

void main() {
  group('parseRulePacksEnabledList', () {
    test('parses enabled ids', () {
      const yaml = '''
plugins:
  saropa_lints:
    version: "1"
    rule_packs:
      enabled:
        - riverpod
        - drift
    diagnostics:
      x: true
''';
      expect(parseRulePacksEnabledList(yaml), ['riverpod', 'drift']);
    });

    test('returns empty when absent', () {
      expect(parseRulePacksEnabledList('plugins:\n  saropa_lints:\n'), isEmpty);
    });

    test('reads legacy migration_packs alias when rule_packs is absent', () {
      const yaml = '''
plugins:
  saropa_lints:
    migration_packs:
      enabled:
        - riverpod
        - drift
''';
      expect(parseRulePacksEnabledList(yaml), ['riverpod', 'drift']);
    });

    test('prefers rule_packs when both keys exist', () {
      const yaml = '''
plugins:
  saropa_lints:
    migration_packs:
      enabled:
        - drift
    rule_packs:
      enabled:
        - riverpod
''';
      expect(parseRulePacksEnabledList(yaml), ['riverpod']);
    });

    test('parses quoted ids and inline comments', () {
      const yaml = '''
plugins:
  saropa_lints:
    rule_packs:
      enabled:
        - "riverpod" # app state
        - 'drift'    # database
''';
      expect(parseRulePacksEnabledList(yaml), ['riverpod', 'drift']);
    });

    test('parses tab-indented blocks', () {
      // Real-world files sometimes use tabs despite YAML spec forbidding them.
      // The parser must count tabs as indentation, not treat them as zero-width.
      const yaml =
          'plugins:\n'
          '\tsaropa_lints:\n'
          '\t\trule_packs:\n'
          '\t\t\tenabled:\n'
          '\t\t\t\t- riverpod\n'
          '\t\t\t\t- drift\n';
      expect(parseRulePacksEnabledList(yaml), ['riverpod', 'drift']);
    });

    test('returns empty for orphan rule_packs key without enabled', () {
      // A bare `rule_packs:` with no children should not crash — just
      // return empty, so migrate-config can still remove the orphan key.
      const yaml = '''
plugins:
  saropa_lints:
    rule_packs:
    diagnostics:
      x: true
''';
      expect(parseRulePacksEnabledList(yaml), isEmpty);
    });

    test('ignores blank lines and comment rows inside enabled block', () {
      const yaml = '''
plugins:
  saropa_lints:
    rule_packs:
      enabled:
        # important packs
        - riverpod

        - drift
    diagnostics:
      x: true
''';
      expect(parseRulePacksEnabledList(yaml), ['riverpod', 'drift']);
    });
  });
}
