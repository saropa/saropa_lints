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
