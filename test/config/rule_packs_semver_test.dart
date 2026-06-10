/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `rule_packs_semver_test` (rule packs semver).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
import 'package:saropa_lints/src/config/rule_packs.dart';
import 'package:test/test.dart';

// Rule pack dependency gates vs pubspec version constraints.

void main() {
  group('packPassesDependencyGate', () {
    test('ungated pack always passes', () {
      expect(packPassesDependencyGate('riverpod', null), isTrue);
      expect(packPassesDependencyGate('riverpod', {}), isTrue);
    });

    test('collection_compat passes when collection satisfies constraint', () {
      expect(
        packPassesDependencyGate('collection_compat', {'collection': '1.19.0'}),
        isTrue,
      );
      expect(
        packPassesDependencyGate('collection_compat', {'collection': '1.19.1'}),
        isTrue,
      );
    });

    test('collection_compat fails when collection too old', () {
      expect(
        packPassesDependencyGate('collection_compat', {'collection': '1.18.0'}),
        isFalse,
      );
    });

    test('collection_compat fails without lock data', () {
      expect(packPassesDependencyGate('collection_compat', null), isFalse);
      expect(packPassesDependencyGate('collection_compat', {}), isFalse);
    });

    // riverpod_2 gates prefer_notifier_over_state on the Notifier API, which
    // only exists in riverpod >= 2.0.0.
    test('riverpod_2 passes when riverpod satisfies >=2.0.0', () {
      expect(
        packPassesDependencyGate('riverpod_2', {'riverpod': '2.0.0'}),
        isTrue,
      );
      expect(
        packPassesDependencyGate('riverpod_2', {'riverpod': '2.5.1'}),
        isTrue,
      );
    });

    test('riverpod_2 fails on riverpod 1.x and without lock data', () {
      expect(
        packPassesDependencyGate('riverpod_2', {'riverpod': '1.0.4'}),
        isFalse,
      );
      expect(packPassesDependencyGate('riverpod_2', null), isFalse);
      expect(packPassesDependencyGate('riverpod_2', {}), isFalse);
    });

    // dio_5 gates avoid_dio_error on the DioError→DioException rename (dio 5.0).
    test('dio_5 passes on dio >=5.0.0, fails on 4.x and without lock', () {
      expect(packPassesDependencyGate('dio_5', {'dio': '5.0.0'}), isTrue);
      expect(packPassesDependencyGate('dio_5', {'dio': '5.4.3'}), isTrue);
      expect(packPassesDependencyGate('dio_5', {'dio': '4.0.6'}), isFalse);
      expect(packPassesDependencyGate('dio_5', null), isFalse);
    });

    // bloc_8 gates avoid_bloc_map_event_to_state on the mapEventToState removal.
    test('bloc_8 passes on bloc >=8.0.0, fails on 7.x and without lock', () {
      expect(packPassesDependencyGate('bloc_8', {'bloc': '8.0.0'}), isTrue);
      expect(packPassesDependencyGate('bloc_8', {'bloc': '8.1.4'}), isTrue);
      expect(packPassesDependencyGate('bloc_8', {'bloc': '7.2.1'}), isFalse);
      expect(packPassesDependencyGate('bloc_8', null), isFalse);
    });

    // riverpod_3 gates the StateNotifier legacy migration on riverpod 3.0.
    test('riverpod_3 passes on riverpod >=3.0.0, fails on 2.x', () {
      expect(
        packPassesDependencyGate('riverpod_3', {'riverpod': '3.0.0'}),
        isTrue,
      );
      expect(
        packPassesDependencyGate('riverpod_3', {'riverpod': '2.5.1'}),
        isFalse,
      );
      expect(packPassesDependencyGate('riverpod_3', null), isFalse);
    });

    // go_router_6 is a whole-pack gate (no relocation) on go_router 6.0.
    test('go_router_6 passes on go_router >=6.0.0, fails on 5.x', () {
      expect(
        packPassesDependencyGate('go_router_6', {'go_router': '6.0.0'}),
        isTrue,
      );
      expect(
        packPassesDependencyGate('go_router_6', {'go_router': '5.2.4'}),
        isFalse,
      );
      expect(packPassesDependencyGate('go_router_6', null), isFalse);
    });

    test('go_router_6 owns avoid_go_router_legacy_redirect', () {
      expect(
        ruleCodesForPack('go_router_6'),
        contains('avoid_go_router_legacy_redirect'),
      );
    });
  });

  group('riverpod_2 ownership', () {
    // The gate is only meaningful if the rule is NOT also in the ungated
    // riverpod pack — otherwise enabling `riverpod` would re-add it regardless
    // of version. See kRelocatedRulePackCodes in tool/rule_pack_audit.dart.
    test('prefer_notifier_over_state is in riverpod_2, not riverpod', () {
      expect(
        ruleCodesForPack('riverpod_2'),
        contains('prefer_notifier_over_state'),
      );
      expect(
        ruleCodesForPack('riverpod'),
        isNot(contains('prefer_notifier_over_state')),
      );
    });

    test('avoid_dio_error is in dio_5, not dio', () {
      expect(ruleCodesForPack('dio_5'), contains('avoid_dio_error'));
      expect(ruleCodesForPack('dio'), isNot(contains('avoid_dio_error')));
    });

    test('avoid_bloc_map_event_to_state is in bloc_8, not bloc', () {
      expect(
        ruleCodesForPack('bloc_8'),
        contains('avoid_bloc_map_event_to_state'),
      );
      expect(
        ruleCodesForPack('bloc'),
        isNot(contains('avoid_bloc_map_event_to_state')),
      );
    });

    test('avoid_riverpod_state_notifier is in riverpod_3, not riverpod', () {
      expect(
        ruleCodesForPack('riverpod_3'),
        contains('avoid_riverpod_state_notifier'),
      );
      expect(
        ruleCodesForPack('riverpod'),
        isNot(contains('avoid_riverpod_state_notifier')),
      );
    });
  });

  group('mergeRulePacksIntoEnabled semver', () {
    test('skips gated pack when version too old', () {
      final enabled = <String>{};
      final contributed = mergeRulePacksIntoEnabled(
        enabled,
        null,
        ['collection_compat'],
        resolvedVersions: {'collection': '1.17.0'},
      );
      expect(enabled, isEmpty);
      expect(contributed, isEmpty);
    });

    test('merges gated pack when version in range', () {
      final enabled = <String>{};
      final contributed = mergeRulePacksIntoEnabled(
        enabled,
        null,
        ['collection_compat'],
        resolvedVersions: {'collection': '1.19.0'},
      );
      expect(
        enabled.contains('avoid_collection_methods_with_unrelated_types'),
        isTrue,
      );
      expect(
        contributed,
        contains('avoid_collection_methods_with_unrelated_types'),
      );
    });

    test('skips gated pack when resolvedVersions omitted', () {
      final enabled = <String>{};
      mergeRulePacksIntoEnabled(enabled, null, ['collection_compat']);
      expect(enabled, isEmpty);
    });

    test('riverpod_2 merges prefer_notifier_over_state only on >=2.0.0', () {
      final oldProject = <String>{};
      mergeRulePacksIntoEnabled(
        oldProject,
        null,
        ['riverpod_2'],
        resolvedVersions: {'riverpod': '1.0.4'},
      );
      expect(oldProject.contains('prefer_notifier_over_state'), isFalse);

      final newProject = <String>{};
      final contributed = mergeRulePacksIntoEnabled(
        newProject,
        null,
        ['riverpod_2'],
        resolvedVersions: {'riverpod': '2.4.0'},
      );
      expect(newProject.contains('prefer_notifier_over_state'), isTrue);
      expect(contributed, contains('prefer_notifier_over_state'));
    });
  });
}
