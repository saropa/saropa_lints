import 'dart:io';

import 'package:saropa_lints/src/rules/packages/isar_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 21 Isar lint rules.
///
/// Test fixtures: example_packages/lib/isar/*
void main() {
  group('Isar Rules - Rule Instantiation', () {
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
      'AvoidIsarEnumFieldRule',
      'avoid_isar_enum_field',
      () => AvoidIsarEnumFieldRule(),
    );
    testRule(
      'RequireIsarCollectionAnnotationRule',
      'require_isar_collection_annotation',
      () => RequireIsarCollectionAnnotationRule(),
    );
    testRule(
      'RequireIsarIdFieldRule',
      'require_isar_id_field',
      () => RequireIsarIdFieldRule(),
    );
    testRule(
      'RequireIsarCloseOnDisposeRule',
      'require_isar_close_on_dispose',
      () => RequireIsarCloseOnDisposeRule(),
    );
    testRule(
      'PreferIsarAsyncWritesRule',
      'prefer_isar_async_writes',
      () => PreferIsarAsyncWritesRule(),
    );
    testRule(
      'AvoidIsarTransactionNestingRule',
      'avoid_isar_transaction_nesting',
      () => AvoidIsarTransactionNestingRule(),
    );
    testRule(
      'PreferIsarBatchOperationsRule',
      'prefer_isar_batch_operations',
      () => PreferIsarBatchOperationsRule(),
    );
    testRule(
      'AvoidIsarFloatEqualityQueriesRule',
      'avoid_isar_float_equality_queries',
      () => AvoidIsarFloatEqualityQueriesRule(),
    );
    testRule(
      'RequireIsarInspectorDebugOnlyRule',
      'require_isar_inspector_debug_only',
      () => RequireIsarInspectorDebugOnlyRule(),
    );
    testRule(
      'AvoidIsarClearInProductionRule',
      'avoid_isar_clear_in_production',
      () => AvoidIsarClearInProductionRule(),
    );
    testRule(
      'RequireIsarLinksLoadRule',
      'require_isar_links_load',
      () => RequireIsarLinksLoadRule(),
    );
    testRule(
      'PreferIsarQueryStreamRule',
      'prefer_isar_query_stream',
      () => PreferIsarQueryStreamRule(),
    );
    testRule(
      'AvoidIsarWebLimitationsRule',
      'avoid_isar_web_limitations',
      () => AvoidIsarWebLimitationsRule(),
    );
    testRule(
      'PreferIsarIndexForQueriesRule',
      'prefer_isar_index_for_queries',
      () => PreferIsarIndexForQueriesRule(),
    );
    testRule(
      'AvoidIsarEmbeddedLargeObjectsRule',
      'avoid_isar_embedded_large_objects',
      () => AvoidIsarEmbeddedLargeObjectsRule(),
    );
    testRule(
      'PreferIsarLazyLinksRule',
      'prefer_isar_lazy_links',
      () => PreferIsarLazyLinksRule(),
    );
    testRule(
      'AvoidIsarSchemaBreakingChangesRule',
      'avoid_isar_schema_breaking_changes',
      () => AvoidIsarSchemaBreakingChangesRule(),
    );
    testRule(
      'RequireIsarNullableFieldRule',
      'require_isar_nullable_field',
      () => RequireIsarNullableFieldRule(),
    );
    testRule(
      'PreferIsarCompositeIndexRule',
      'prefer_isar_composite_index',
      () => PreferIsarCompositeIndexRule(),
    );
    testRule(
      'AvoidIsarStringContainsWithoutIndexRule',
      'avoid_isar_string_contains_without_index',
      () => AvoidIsarStringContainsWithoutIndexRule(),
    );
    testRule(
      'AvoidCachedIsarStreamRule',
      'avoid_cached_isar_stream',
      () => AvoidCachedIsarStreamRule(),
    );
  });
  group('Isar Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/isar');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_packages/lib/isar/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
