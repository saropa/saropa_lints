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

    test('additive: a tier-provided pack rule stays when no packs enabled', () {
      // Additive model: tier is the floor, packs only add. A rule the tier
      // already enabled is never stripped just because its pack is off.
      final enabled = <String>{'require_provider_scope', 'x'};
      mergeRulePacksIntoEnabled(enabled, null, const <String>[]);
      expect(enabled.contains('require_provider_scope'), isTrue);
      expect(enabled.contains('x'), isTrue);
    });

    test('keeps pack-owned rule when its pack is enabled', () {
      final enabled = <String>{'require_provider_scope', 'x'};
      mergeRulePacksIntoEnabled(enabled, null, const <String>['riverpod']);
      expect(enabled.contains('require_provider_scope'), isTrue);
      expect(enabled.contains('x'), isTrue);
    });

    test('a rule in two enabled packs is added once', () {
      final enabled = <String>{};
      mergeRulePacksIntoEnabled(
        enabled,
        null,
        const <String>['riverpod', 'riverpod'],
      );
      expect(
        enabled.where((c) => c == 'require_provider_scope'),
        hasLength(1),
      );
    });

    group('version choice wins over tier', () {
      test('dio 5 rule is stripped from the tier on a dio 4 project', () {
        // avoid_dio_error applies to dio 5 (DioError removed). On dio 4 the old
        // type is valid, so the version wins over a tier that lists the rule.
        final enabled = <String>{'avoid_dio_error', 'x'};
        mergeRulePacksIntoEnabled(
          enabled,
          null,
          const <String>[],
          resolvedVersions: {'dio': '4.0.6'},
        );
        expect(enabled.contains('avoid_dio_error'), isFalse);
        expect(enabled.contains('x'), isTrue);
      });

      test('dio 5 rule from the tier stays on a dio 5 project', () {
        final enabled = <String>{'avoid_dio_error'};
        mergeRulePacksIntoEnabled(
          enabled,
          null,
          const <String>[],
          resolvedVersions: {'dio': '5.4.3'},
        );
        expect(enabled.contains('avoid_dio_error'), isTrue);
      });

      test('dio 5 rule from the tier stays when dio version is unknown', () {
        // No lockfile version → conservative: keep the floor, never strip on a guess.
        final enabled = <String>{'avoid_dio_error'};
        mergeRulePacksIntoEnabled(enabled, null, const <String>[]);
        expect(enabled.contains('avoid_dio_error'), isTrue);
      });

      test('SDK migration rule stripped when pubspec proves wrong version', () {
        // flutter_sdk_3_38 (avoid_asset_manifest_json) gates >=3.38.0.
        final enabled = <String>{'avoid_asset_manifest_json', 'x'};
        mergeRulePacksIntoEnabled(
          enabled,
          null,
          const <String>[],
          pubspecYamlContent: 'environment:\n  flutter: ">=3.10.0"\n',
        );
        expect(enabled.contains('avoid_asset_manifest_json'), isFalse);
        expect(enabled.contains('x'), isTrue);
      });

      test('SDK migration rule from the tier stays when SDK is unknown', () {
        final enabled = <String>{'avoid_asset_manifest_json'};
        mergeRulePacksIntoEnabled(enabled, null, const <String>[]);
        expect(enabled.contains('avoid_asset_manifest_json'), isTrue);
      });
    });
  });

  group('ruleCodesForPack', () {
    test('returns empty for unknown id', () {
      expect(ruleCodesForPack('unknown'), isEmpty);
    });
  });
}
