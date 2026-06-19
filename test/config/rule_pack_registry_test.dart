/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `rule_pack_registry_test` (rule pack registry).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
import 'package:saropa_lints/src/config/rule_packs.dart';
import 'package:test/test.dart';

// rule_packs registry: composite packs and generated rule membership.

void main() {
  group('generated registry + composite packs', () {
    test('avoid_isar_import_with_drift is in both drift and isar packs', () {
      expect(
        ruleCodesForPack('drift'),
        contains('avoid_isar_import_with_drift'),
      );
      expect(
        ruleCodesForPack('isar'),
        contains('avoid_isar_import_with_drift'),
      );
    });

    test('collection_compat is merged on top of generated map', () {
      expect(
        ruleCodesForPack('collection_compat'),
        equals({'avoid_collection_methods_with_unrelated_types'}),
      );
      expect(knownRulePackIds, contains('collection_compat'));
    });

    // Thematic ("quality standard") packs are hand-added to kRulePackRuleCodes
    // (not extracted from lib/src/rules/packages/). Verify each is registered,
    // non-empty, and carries a representative member.
    test('thematic packs are registered with rosters', () {
      const Map<String, String> sentinels = <String, String>{
        'ui_excellence': 'require_keyboard_dismiss_on_scroll',
        'localization': 'avoid_hardcoded_strings_in_ui',
        'documentation': 'require_public_api_documentation',
        'testing': 'require_arrange_act_assert',
      };
      for (final entry in sentinels.entries) {
        expect(knownRulePackIds, contains(entry.key));
        expect(ruleCodesForPack(entry.key), isNotEmpty);
        expect(ruleCodesForPack(entry.key), contains(entry.value));
      }
    });
  });
}
