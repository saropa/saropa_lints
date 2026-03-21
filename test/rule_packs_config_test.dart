import 'package:saropa_lints/src/config/rule_packs.dart';
import 'package:test/test.dart';

void main() {
  group('mergeRulePacksIntoEnabled', () {
    test('adds riverpod pack rules to enabled set', () {
      final enabled = <String>{'some_other_rule'};
      final added = mergeRulePacksIntoEnabled(enabled, null, ['riverpod']);
      expect(added, isNotEmpty);
      expect(enabled.contains('require_provider_scope'), isTrue);
      expect(enabled.contains('some_other_rule'), isTrue);
    });

    test('does not add rules that are in disabled set', () {
      final enabled = <String>{};
      final disabled = <String>{'require_provider_scope'};
      mergeRulePacksIntoEnabled(enabled, disabled, ['riverpod']);
      expect(enabled.contains('require_provider_scope'), isFalse);
      expect(enabled.contains('avoid_riverpod_state_mutation'), isTrue);
    });

    test('disabled match is case-insensitive', () {
      final enabled = <String>{};
      mergeRulePacksIntoEnabled(enabled, {'REQUIRE_PROVIDER_SCOPE'}, ['riverpod']);
      expect(enabled.contains('require_provider_scope'), isFalse);
    });

    test('unknown pack id adds nothing', () {
      final enabled = <String>{};
      mergeRulePacksIntoEnabled(enabled, null, ['nonexistent_pack_xyz']);
      expect(enabled, isEmpty);
    });

    test('empty pack list leaves enabled unchanged', () {
      final enabled = <String>{'x'};
      mergeRulePacksIntoEnabled(enabled, null, <String>[]);
      expect(enabled, equals(<String>{'x'}));
    });
  });

  group('ruleCodesForPack', () {
    test('returns empty for unknown id', () {
      expect(ruleCodesForPack('unknown'), isEmpty);
    });
  });
}
