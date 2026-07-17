import 'dart:io';

import 'package:saropa_lints/src/rules/data/collection_rules.dart';
import 'package:test/test.dart';

/// Tests for 27 Collection lint rules.
///
/// Test fixtures: example/lib/collection/*
// List/Set/Map idioms; large instantiation table then optional integration cases.
void main() {
  group('Collection Rules - Rule Instantiation', () {
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
      'AvoidCollectionEqualityChecksRule',
      'avoid_collection_equality_checks',
      () => AvoidCollectionEqualityChecksRule(),
    );
    testRule(
      'AvoidDuplicateMapKeysRule',
      'avoid_duplicate_map_keys',
      () => AvoidDuplicateMapKeysRule(),
    );
    testRule(
      'AvoidMapKeysContainsRule',
      'avoid_map_keys_contains',
      () => AvoidMapKeysContainsRule(),
    );
    testRule(
      'AvoidUnnecessaryCollectionsRule',
      'avoid_unnecessary_collections',
      () => AvoidUnnecessaryCollectionsRule(),
    );
    testRule(
      'AvoidUnsafeCollectionMethodsRule',
      'avoid_unsafe_collection_methods',
      () => AvoidUnsafeCollectionMethodsRule(),
    );
    testRule(
      'AvoidUnsafeReduceRule',
      'avoid_unsafe_reduce',
      () => AvoidUnsafeReduceRule(),
    );
    testRule(
      'PreferFoldOverReduceRule',
      'prefer_fold_over_reduce',
      () => PreferFoldOverReduceRule(),
    );
    testRule(
      'PreferForeachRule',
      'prefer_for_in_over_foreach',
      () => PreferForeachRule(),
    );
    testRule(
      'PreferForeachOverMapEntriesRule',
      'prefer_foreach_over_map_entries',
      () => PreferForeachOverMapEntriesRule(),
    );
    testRule(
      'PreferConstructorOverLiteralsRule',
      'prefer_constructor_over_literals',
      () => PreferConstructorOverLiteralsRule(),
    );
    testRule(
      'AvoidUnsafeWhereMethodsRule',
      'avoid_unsafe_where_methods',
      () => AvoidUnsafeWhereMethodsRule(),
    );
    testRule(
      'PreferWhereOrNullRule',
      'prefer_where_or_null',
      () => PreferWhereOrNullRule(),
    );
    testRule(
      'MapKeysOrderingRule',
      'map_keys_ordering',
      () => MapKeysOrderingRule(),
    );
    testRule(
      'PreferContainsRule',
      'prefer_list_contains',
      () => PreferContainsRule(),
    );
    testRule('PreferFirstRule', 'prefer_list_first', () => PreferFirstRule());
    testRule(
      'PreferIterableOfRule',
      'prefer_iterable_of',
      () => PreferIterableOfRule(),
    );
    testRule('PreferLastRule', 'prefer_list_last', () => PreferLastRule());
    testRule('PreferAddAllRule', 'prefer_add_all', () => PreferAddAllRule());
    testRule(
      'AvoidDuplicateNumberElementsRule',
      'avoid_duplicate_number_elements',
      () => AvoidDuplicateNumberElementsRule(),
    );
    testRule(
      'AvoidDuplicateStringElementsRule',
      'avoid_duplicate_string_elements',
      () => AvoidDuplicateStringElementsRule(),
    );
    testRule(
      'AvoidDuplicateObjectElementsRule',
      'avoid_duplicate_object_elements',
      () => AvoidDuplicateObjectElementsRule(),
    );
    testRule(
      'PreferSetForLookupRule',
      'prefer_set_for_lookup',
      () => PreferSetForLookupRule(),
    );
    testRule(
      'PreferCorrectForLoopIncrementRule',
      'prefer_correct_for_loop_increment',
      () => PreferCorrectForLoopIncrementRule(),
    );
    testRule(
      'AvoidUnreachableForLoopRule',
      'avoid_unreachable_for_loop',
      () => AvoidUnreachableForLoopRule(),
    );
    testRule(
      'PreferNullAwareElementsRule',
      'prefer_null_aware_elements',
      () => PreferNullAwareElementsRule(),
    );
    testRule(
      'PreferIterableOperationsRule',
      'prefer_iterable_operations',
      () => PreferIterableOperationsRule(),
    );
    testRule(
      'RequireKeyForCollectionRule',
      'require_key_for_collection',
      () => RequireKeyForCollectionRule(),
    );
    testRule(
      'AvoidFunctionLiteralsInForeachCallsRule',
      'avoid_function_literals_in_foreach_calls',
      () => AvoidFunctionLiteralsInForeachCallsRule(),
    );
    testRule(
      'PreferInlinedAddsRule',
      'prefer_inlined_adds',
      () => PreferInlinedAddsRule(),
    );
    testRule(
      'PreferAsmapOverIndexedIterationRule',
      'prefer_asmap_over_indexed_iteration',
      () => PreferAsmapOverIndexedIterationRule(),
    );
    testRule(
      'RequireConstListItemsRule',
      'require_const_list_items',
      () => RequireConstListItemsRule(),
    );
  });

  group('Collection Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/collection');

    // Auto-discover fixtures from disk so new files are verified

    // automatically — no manual list to maintain.

    final fixtures =
        fixtureDir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('_fixture.dart'))
            .map((name) => name.replaceAll('_fixture.dart', ''))
            .toList()
          ..sort();

    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/collection/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Collection - Avoidance Rules', () {
    group('avoid_duplicate_map_keys', () {
      test('rule offers quick fix (remove duplicate entry)', () {
        final rule = AvoidDuplicateMapKeysRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('avoid_duplicate_number_elements', () {
      test('rule offers quick fix (remove duplicate element)', () {
        final rule = AvoidDuplicateNumberElementsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('avoid_duplicate_string_elements', () {
      test('rule offers quick fix (remove duplicate element)', () {
        final rule = AvoidDuplicateStringElementsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('avoid_duplicate_object_elements', () {
      test('rule offers quick fix (remove duplicate element)', () {
        final rule = AvoidDuplicateObjectElementsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('require_const_list_items', () {
      test('rule offers quick fix (add const to list item)', () {
        final rule = RequireConstListItemsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata,
  // fixture verification, and targeted quick-fix checks.

  group('Collection - Map Rules', () {
    group('prefer_for_elements_to_map_from_iterable', () {
      test('rule instantiation', () {
        final rule = PreferForElementsToMapFromIterableRule();
        expect(
          rule.code.lowerCaseName,
          'prefer_for_elements_to_map_from_iterable',
        );
        expect(
          rule.code.problemMessage,
          contains('[prefer_for_elements_to_map_from_iterable]'),
        );
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    });
  });
}
