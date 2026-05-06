/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `rule_packs_config_test` (rule packs config).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
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
      mergeRulePacksIntoEnabled(
        enabled,
        {'REQUIRE_PROVIDER_SCOPE'},
        ['riverpod'],
      );
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

    test('removes pack-owned tier rule when no packs are enabled', () {
      final enabled = <String>{'require_provider_scope', 'x'};
      mergeRulePacksIntoEnabled(enabled, null, const <String>[]);
      expect(enabled.contains('require_provider_scope'), isFalse);
      expect(enabled.contains('x'), isTrue);
    });

    test('keeps pack-owned rule only when its pack is enabled', () {
      final enabled = <String>{'require_provider_scope', 'x'};
      mergeRulePacksIntoEnabled(enabled, null, const <String>['riverpod']);
      expect(enabled.contains('require_provider_scope'), isTrue);
      expect(enabled.contains('x'), isTrue);
    });

    test(
      'pack-owned diagnostics true is ignored unless owning pack is enabled',
      () {
        // Simulates diagnostics: require_provider_scope: true with no pack
        // selected. In authoritative pack mode, pack-owned rules are only
        // active when their owning pack is enabled.
        final enabled = <String>{'require_provider_scope', 'x'};
        mergeRulePacksIntoEnabled(enabled, null, const <String>[]);
        expect(enabled.contains('require_provider_scope'), isFalse);
        expect(enabled.contains('x'), isTrue);
      },
    );

    test(
      'sdk/flutter pack migration codes require an enabled pack (not tier-only)',
      () {
        final sdkCodes = kRulePackRuleCodes.keys
            .where(
              (id) =>
                  id.startsWith('dart_sdk_') || id.startsWith('flutter_sdk_'),
            )
            .expand((id) => kRulePackRuleCodes[id] ?? const <String>{})
            .toSet();
        expect(sdkCodes, isNotEmpty);
        for (final code in sdkCodes) {
          final enabled = <String>{code};
          mergeRulePacksIntoEnabled(enabled, null, const <String>[]);
          expect(
            enabled.contains(code),
            isFalse,
            reason:
                'Pack-owned SDK migration code $code must require an enabled pack',
          );
        }
      },
    );
  });

  group('ruleCodesForPack', () {
    test('returns empty for unknown id', () {
      expect(ruleCodesForPack('unknown'), isEmpty);
    });
  });
}
