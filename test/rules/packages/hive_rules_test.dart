import 'dart:io';

import 'package:saropa_lints/src/rules/packages/hive_rules.dart';
import 'package:test/test.dart';

/// Tests for 23 Hive lint rules.
///
/// Test fixtures: example_packages/lib/hive/*
void main() {
  group('Hive Rules - Rule Instantiation', () {
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
      'RequireHiveInitializationRule',
      'require_hive_initialization',
      () => RequireHiveInitializationRule(),
    );
    testRule(
      'RequireHiveTypeAdapterRule',
      'require_hive_type_adapter',
      () => RequireHiveTypeAdapterRule(),
    );
    testRule(
      'RequireHiveBoxCloseRule',
      'require_hive_box_close',
      () => RequireHiveBoxCloseRule(),
    );
    testRule(
      'PreferHiveEncryptionRule',
      'prefer_hive_encryption',
      () => PreferHiveEncryptionRule(),
    );
    testRule(
      'RequireHiveEncryptionKeySecureRule',
      'require_hive_encryption_key_secure',
      () => RequireHiveEncryptionKeySecureRule(),
    );
    testRule(
      'RequireHiveDatabaseCloseRule',
      'require_hive_database_close',
      () => RequireHiveDatabaseCloseRule(),
    );
    testRule(
      'RequireTypeAdapterRegistrationRule',
      'require_type_adapter_registration',
      () => RequireTypeAdapterRegistrationRule(),
    );
    testRule(
      'PreferLazyBoxForLargeRule',
      'prefer_lazy_box_for_large',
      () => PreferLazyBoxForLargeRule(),
    );
    testRule(
      'RequireHiveTypeIdManagementRule',
      'require_hive_type_id_management',
      () => RequireHiveTypeIdManagementRule(),
    );
    testRule(
      'AvoidHiveFieldIndexReuseRule',
      'avoid_hive_field_index_reuse',
      () => AvoidHiveFieldIndexReuseRule(),
    );
    testRule(
      'RequireHiveFieldDefaultValueRule',
      'require_hive_field_default_value',
      () => RequireHiveFieldDefaultValueRule(),
    );
    testRule(
      'RequireHiveAdapterRegistrationOrderRule',
      'require_hive_adapter_registration_order',
      () => RequireHiveAdapterRegistrationOrderRule(),
    );
    testRule(
      'RequireHiveNestedObjectAdapterRule',
      'require_hive_nested_object_adapter',
      () => RequireHiveNestedObjectAdapterRule(),
    );
    testRule(
      'AvoidHiveBoxNameCollisionRule',
      'avoid_hive_box_name_collision',
      () => AvoidHiveBoxNameCollisionRule(),
    );
    testRule(
      'PreferHiveValueListenableRule',
      'prefer_hive_value_listenable',
      () => PreferHiveValueListenableRule(),
    );
    testRule(
      'PreferHiveLazyBoxRule',
      'prefer_hive_lazy_box',
      () => PreferHiveLazyBoxRule(),
    );
    testRule(
      'AvoidHiveBinaryStorageRule',
      'avoid_hive_binary_storage',
      () => AvoidHiveBinaryStorageRule(),
    );
    testRule(
      'RequireHiveMigrationStrategyRule',
      'require_hive_migration_strategy',
      () => RequireHiveMigrationStrategyRule(),
    );
    testRule(
      'AvoidHiveSynchronousInUiRule',
      'avoid_hive_synchronous_in_ui',
      () => AvoidHiveSynchronousInUiRule(),
    );
    testRule(
      'RequireHiveWebSubdirectoryRule',
      'require_hive_web_subdirectory',
      () => RequireHiveWebSubdirectoryRule(),
    );
    testRule(
      'AvoidHiveDatetimeLocalRule',
      'avoid_hive_datetime_local',
      () => AvoidHiveDatetimeLocalRule(),
    );
    testRule(
      'AvoidHiveTypeModificationRule',
      'avoid_hive_type_modification',
      () => AvoidHiveTypeModificationRule(),
    );
    testRule(
      'AvoidHiveLargeSingleEntryRule',
      'avoid_hive_large_single_entry',
      () => AvoidHiveLargeSingleEntryRule(),
    );
  });
  group('Hive Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/hive');

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
      test('\$fixture fixture exists', () {
        final file = File('example_packages/lib/hive/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
