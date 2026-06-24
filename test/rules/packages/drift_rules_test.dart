import 'dart:io';

import 'package:saropa_lints/src/rules/packages/drift_rules.dart';
import 'package:test/test.dart';

/// Tests for 31 Drift database lint rules.
///
/// Test fixtures: example_packages/lib/drift/*
// Drift schema, SQL, and migration patterns; uses example_packages Drift package.
void main() {
  group('Drift Rules - Rule Instantiation', () {
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
      'AvoidDriftEnumIndexReorderRule',
      'avoid_drift_enum_index_reorder',
      () => AvoidDriftEnumIndexReorderRule(),
    );

    test('AvoidDriftEnumIndexReorderRule exposes a quick fix', () {
      expect(AvoidDriftEnumIndexReorderRule().fixGenerators, isNotEmpty);
    });

    testRule(
      'RequireDriftDatabaseCloseRule',
      'require_drift_database_close',
      () => RequireDriftDatabaseCloseRule(),
    );

    testRule(
      'AvoidDriftUpdateWithoutWhereRule',
      'avoid_drift_update_without_where',
      () => AvoidDriftUpdateWithoutWhereRule(),
    );

    testRule(
      'AvoidDriftInsertMissingConflictTargetRule',
      'avoid_drift_insert_missing_conflict_target',
      () => AvoidDriftInsertMissingConflictTargetRule(),
    );

    testRule(
      'RequireAwaitInDriftTransactionRule',
      'require_await_in_drift_transaction',
      () => RequireAwaitInDriftTransactionRule(),
    );

    testRule(
      'RequireDriftForeignKeyPragmaRule',
      'require_drift_foreign_key_pragma',
      () => RequireDriftForeignKeyPragmaRule(),
    );

    testRule(
      'AvoidDriftRawSqlInterpolationRule',
      'avoid_drift_raw_sql_interpolation',
      () => AvoidDriftRawSqlInterpolationRule(),
    );

    testRule(
      'PreferDriftBatchOperationsRule',
      'prefer_drift_batch_operations',
      () => PreferDriftBatchOperationsRule(),
    );

    testRule(
      'RequireDriftStreamCancelRule',
      'require_drift_stream_cancel',
      () => RequireDriftStreamCancelRule(),
    );

    testRule(
      'AvoidDriftDatabaseOnMainIsolateRule',
      'avoid_drift_database_on_main_isolate',
      () => AvoidDriftDatabaseOnMainIsolateRule(),
    );

    testRule(
      'AvoidDriftLogStatementsProductionRule',
      'avoid_drift_log_statements_production',
      () => AvoidDriftLogStatementsProductionRule(),
    );

    testRule(
      'AvoidDriftGetSingleWithoutUniqueRule',
      'avoid_drift_get_single_without_unique',
      () => AvoidDriftGetSingleWithoutUniqueRule(),
    );

    testRule(
      'PreferDriftUseColumnsFalseRule',
      'prefer_drift_use_columns_false',
      () => PreferDriftUseColumnsFalseRule(),
    );

    testRule(
      'AvoidDriftLazyDatabaseRule',
      'avoid_drift_lazy_database',
      () => AvoidDriftLazyDatabaseRule(),
    );

    testRule(
      'PreferDriftIsolateSharingRule',
      'prefer_drift_isolate_sharing',
      () => PreferDriftIsolateSharingRule(),
    );

    testRule(
      'AvoidDriftQueryInMigrationRule',
      'avoid_drift_query_in_migration',
      () => AvoidDriftQueryInMigrationRule(),
    );

    testRule(
      'RequireDriftSchemaVersionBumpRule',
      'require_drift_schema_version_bump',
      () => RequireDriftSchemaVersionBumpRule(),
    );

    testRule(
      'AvoidDriftForeignKeyInMigrationRule',
      'avoid_drift_foreign_key_in_migration',
      () => AvoidDriftForeignKeyInMigrationRule(),
    );

    testRule(
      'RequireDriftReadsFromRule',
      'require_drift_reads_from',
      () => RequireDriftReadsFromRule(),
    );

    testRule(
      'AvoidDriftUnsafeWebStorageRule',
      'avoid_drift_unsafe_web_storage',
      () => AvoidDriftUnsafeWebStorageRule(),
    );

    testRule(
      'AvoidDriftCloseStreamsInTestsRule',
      'avoid_drift_close_streams_in_tests',
      () => AvoidDriftCloseStreamsInTestsRule(),
    );

    testRule(
      'AvoidDriftNullableConverterMismatchRule',
      'avoid_drift_nullable_converter_mismatch',
      () => AvoidDriftNullableConverterMismatchRule(),
    );

    testRule(
      'AvoidDriftValueNullVsAbsentRule',
      'avoid_drift_value_null_vs_absent',
      () => AvoidDriftValueNullVsAbsentRule(),
    );

    testRule(
      'RequireDriftEqualsValueRule',
      'require_drift_equals_value',
      () => RequireDriftEqualsValueRule(),
    );

    testRule(
      'RequireDriftReadTableOrNullRule',
      'require_drift_read_table_or_null',
      () => RequireDriftReadTableOrNullRule(),
    );

    testRule(
      'RequireDriftCreateAllInOnCreateRule',
      'require_drift_create_all_in_oncreate',
      () => RequireDriftCreateAllInOnCreateRule(),
    );

    testRule(
      'AvoidDriftValidateSchemaProductionRule',
      'avoid_drift_validate_schema_production',
      () => AvoidDriftValidateSchemaProductionRule(),
    );

    testRule(
      'AvoidDriftReplaceWithoutAllColumnsRule',
      'avoid_drift_replace_without_all_columns',
      () => AvoidDriftReplaceWithoutAllColumnsRule(),
    );

    testRule(
      'AvoidDriftMissingUpdatesParamRule',
      'avoid_drift_missing_updates_param',
      () => AvoidDriftMissingUpdatesParamRule(),
    );

    testRule(
      'AvoidIsarImportWithDriftRule',
      'avoid_isar_import_with_drift',
      () => AvoidIsarImportWithDriftRule(),
    );

    testRule(
      'PreferDriftForeignKeyDeclarationRule',
      'prefer_drift_foreign_key_declaration',
      () => PreferDriftForeignKeyDeclarationRule(),
    );

    testRule(
      'RequireDriftOnUpgradeHandlerRule',
      'require_drift_onupgrade_handler',
      () => RequireDriftOnUpgradeHandlerRule(),
    );

    testRule(
      'RequireNamedForAcronymDriftColumnsRule',
      'require_named_for_acronym_drift_columns',
      () => RequireNamedForAcronymDriftColumnsRule(),
    );
  });

  group('Drift Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_drift_enum_index_reorder',
      'avoid_drift_insert_missing_conflict_target',
      'require_drift_database_close',
      'avoid_drift_update_without_where',
      'require_await_in_drift_transaction',
      'require_drift_foreign_key_pragma',
      'avoid_drift_raw_sql_interpolation',
      'prefer_drift_batch_operations',
      'require_drift_stream_cancel',
      'avoid_drift_database_on_main_isolate',
      'avoid_drift_log_statements_production',
      'avoid_drift_get_single_without_unique',
      'prefer_drift_use_columns_false',
      'avoid_drift_lazy_database',
      'prefer_drift_isolate_sharing',
      'avoid_drift_query_in_migration',
      'require_drift_schema_version_bump',
      'avoid_drift_foreign_key_in_migration',
      'require_drift_reads_from',
      'avoid_drift_unsafe_web_storage',
      'avoid_drift_close_streams_in_tests',
      'avoid_drift_nullable_converter_mismatch',
      'avoid_drift_value_null_vs_absent',
      'require_drift_equals_value',
      'require_drift_read_table_or_null',
      'require_drift_create_all_in_oncreate',
      'avoid_drift_validate_schema_production',
      'avoid_drift_replace_without_all_columns',
      'avoid_drift_missing_updates_param',
      'avoid_isar_import_with_drift',
      'prefer_drift_foreign_key_declaration',
      'require_drift_onupgrade_handler',
      'require_named_for_acronym_drift_columns',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_packages/lib/drift/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture checks while migrating to analyzer-backed behavior tests.
}
