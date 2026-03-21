import 'package:saropa_lints/src/config/analysis_options_rule_packs.dart';
import 'package:test/test.dart';

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
  });
}
