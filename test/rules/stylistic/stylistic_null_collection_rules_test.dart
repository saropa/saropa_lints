import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/stylistic_null_collection_rules.dart';

/// Tests for 14 Stylistic Null Collection lint rules.
///
/// Test fixtures: example/lib/stylistic_null_collection/*
void main() {
  group('Stylistic Null Collection Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'PreferNullAwareAssignmentRule',
      'prefer_null_aware_assignment',
      () => PreferNullAwareAssignmentRule(),
    );

    testRule(
      'PreferExplicitNullAssignmentRule',
      'prefer_explicit_null_assignment',
      () => PreferExplicitNullAssignmentRule(),
    );

    testRule(
      'PreferIfNullOverTernaryRule',
      'prefer_if_null_over_ternary',
      () => PreferIfNullOverTernaryRule(),
    );

    testRule(
      'PreferTernaryOverIfNullRule',
      'prefer_ternary_over_if_null',
      () => PreferTernaryOverIfNullRule(),
    );

    testRule(
      'PreferLateOverNullableRule',
      'prefer_late_over_nullable',
      () => PreferLateOverNullableRule(),
    );

    testRule(
      'PreferNullableOverLateRule',
      'prefer_nullable_over_late',
      () => PreferNullableOverLateRule(),
    );

    testRule(
      'PreferSpreadOverAddAllRule',
      'prefer_spread_over_addall',
      () => PreferSpreadOverAddAllRule(),
    );

    testRule(
      'PreferAddAllOverSpreadRule',
      'prefer_addall_over_spread',
      () => PreferAddAllOverSpreadRule(),
    );

    testRule(
      'PreferCollectionIfOverTernaryRule',
      'prefer_collection_if_over_ternary',
      () => PreferCollectionIfOverTernaryRule(),
    );

    testRule(
      'PreferTernaryOverCollectionIfRule',
      'prefer_ternary_over_collection_if',
      () => PreferTernaryOverCollectionIfRule(),
    );

    testRule(
      'PreferWhereTypeOverWhereIsRule',
      'prefer_wheretype_over_where_is',
      () => PreferWhereTypeOverWhereIsRule(),
    );

    testRule(
      'PreferMapEntriesIterationRule',
      'prefer_map_entries_iteration',
      () => PreferMapEntriesIterationRule(),
    );

    testRule(
      'PreferKeysIterationRule',
      'prefer_keys_with_lookup',
      () => PreferKeysIterationRule(),
    );

    testRule(
      'PreferMutableCollectionsRule',
      'prefer_mutable_collections',
      () => PreferMutableCollectionsRule(),
    );
  });

  group('Stylistic Null Collection Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_null_aware_assignment',
      'prefer_explicit_null_assignment',
      'prefer_if_null_over_ternary',
      'prefer_ternary_over_if_null',
      'prefer_late_over_nullable',
      'prefer_nullable_over_late',
      'prefer_spread_over_addall',
      'prefer_addall_over_spread',
      'prefer_collection_if_over_ternary',
      'prefer_ternary_over_collection_if',
      'prefer_wheretype_over_where_is',
      'prefer_map_entries_iteration',
      'prefer_keys_with_lookup',
      'prefer_mutable_collections',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/stylistic_null_collection/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
