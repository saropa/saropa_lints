import 'package:saropa_lints/src/config/rule_packs.dart';
import 'package:test/test.dart';

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
      expect(contributed, contains('avoid_collection_methods_with_unrelated_types'));
    });

    test('skips gated pack when resolvedVersions omitted', () {
      final enabled = <String>{};
      mergeRulePacksIntoEnabled(enabled, null, ['collection_compat']);
      expect(enabled, isEmpty);
    });
  });
}
