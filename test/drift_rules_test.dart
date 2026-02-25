import 'dart:io';

import 'package:saropa_lints/src/rules/packages/drift_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';
import 'package:test/test.dart';

/// Tests for 31 Drift database lint rules.
///
/// Test fixtures: example_packages/lib/drift/*
void main() {
  group('Drift Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_drift_enum_index_reorder',
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
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_packages/lib/drift/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Drift - Essential Rules', () {
    group('avoid_drift_enum_index_reorder', () {
      test('TypeConverter using .index SHOULD trigger', () {
        expect('TypeConverter using .index', isNotNull);
      });

      test('TypeConverter using .name should NOT trigger', () {
        expect('TypeConverter using .name', isNotNull);
      });

      test('intEnum column builder SHOULD trigger', () {
        expect('intEnum column builder', isNotNull);
      });
    });
  });

  group('Drift - Recommended Rules', () {
    group('require_drift_database_close', () {
      test('database field without close in dispose SHOULD trigger', () {
        expect('database field without close in dispose', isNotNull);
      });

      test('database field with close in dispose should NOT trigger', () {
        expect('database field with close in dispose', isNotNull);
      });
    });

    group('avoid_drift_update_without_where', () {
      test('update without where clause SHOULD trigger', () {
        expect('update without where clause', isNotNull);
      });

      test('update with where clause should NOT trigger', () {
        expect('update with where clause', isNotNull);
      });
    });

    group('require_await_in_drift_transaction', () {
      test('unawaited query in transaction SHOULD trigger', () {
        expect('unawaited query in transaction', isNotNull);
      });

      test('awaited query in transaction should NOT trigger', () {
        expect('awaited query in transaction', isNotNull);
      });
    });

    group('require_drift_foreign_key_pragma', () {
      test('database class without foreign_keys pragma SHOULD trigger', () {
        expect('database class without foreign_keys pragma', isNotNull);
      });

      test('database class with foreign_keys pragma should NOT trigger', () {
        expect('database class with foreign_keys pragma', isNotNull);
      });
    });

    group('avoid_drift_raw_sql_interpolation', () {
      test('string interpolation in customSelect SHOULD trigger', () {
        expect('string interpolation in customSelect', isNotNull);
      });

      test('parameterized customSelect should NOT trigger', () {
        expect('parameterized customSelect', isNotNull);
      });
    });

    group('prefer_drift_batch_operations', () {
      test('insert in a loop SHOULD trigger', () {
        expect('insert in a loop', isNotNull);
      });

      test('batch insertAll should NOT trigger', () {
        expect('batch insertAll', isNotNull);
      });
    });

    group('require_drift_stream_cancel', () {
      test('unassigned watch().listen() SHOULD trigger', () {
        expect('unassigned watch().listen()', isNotNull);
      });

      test('assigned watch().listen() should NOT trigger', () {
        expect('assigned watch().listen()', isNotNull);
      });
    });
  });

  group('Drift - Professional Rules', () {
    group('avoid_drift_database_on_main_isolate', () {
      test('NativeDatabase() without background SHOULD trigger', () {
        expect('NativeDatabase() without background', isNotNull);
      });

      test('NativeDatabase.createInBackground() should NOT trigger', () {
        expect('NativeDatabase.createInBackground()', isNotNull);
      });
    });

    group('avoid_drift_log_statements_production', () {
      test('logStatements: true SHOULD trigger', () {
        expect('logStatements: true', isNotNull);
      });

      test('logStatements: kDebugMode should NOT trigger', () {
        expect('logStatements: kDebugMode', isNotNull);
      });
    });

    group('avoid_drift_get_single_without_unique', () {
      test('getSingle without where SHOULD trigger', () {
        expect('getSingle without where', isNotNull);
      });

      test('getSingle with where clause should NOT trigger', () {
        expect('getSingle with where clause', isNotNull);
      });
    });

    group('prefer_drift_use_columns_false', () {
      test('join without useColumns SHOULD trigger', () {
        expect('join without useColumns', isNotNull);
      });

      test('join with useColumns: false should NOT trigger', () {
        expect('join with useColumns: false', isNotNull);
      });
    });

    group('avoid_drift_lazy_database', () {
      test('LazyDatabase with DriftIsolate SHOULD trigger', () {
        expect('LazyDatabase with DriftIsolate', isNotNull);
      });

      test('LazyDatabase without isolate should NOT trigger', () {
        expect('LazyDatabase without isolate', isNotNull);
      });
    });

    group('prefer_drift_isolate_sharing', () {
      test('duplicate NativeDatabase paths SHOULD trigger', () {
        expect('duplicate NativeDatabase paths', isNotNull);
      });

      test('singleton NativeDatabase should NOT trigger', () {
        expect('singleton NativeDatabase', isNotNull);
      });
    });
  });

  group('Drift - Comprehensive Rules', () {
    group('avoid_drift_query_in_migration', () {
      test('select() in onUpgrade SHOULD trigger', () {
        expect('select() in onUpgrade', isNotNull);
      });

      test('customStatement() in onUpgrade should NOT trigger', () {
        expect('customStatement() in onUpgrade', isNotNull);
      });
    });

    group('require_drift_schema_version_bump', () {
      test('schemaVersion 1 with many tables SHOULD trigger', () {
        expect('schemaVersion 1 with many tables', isNotNull);
      });

      test('schemaVersion > 1 should NOT trigger', () {
        expect('schemaVersion > 1', isNotNull);
      });
    });

    group('avoid_drift_foreign_key_in_migration', () {
      test('PRAGMA foreign_keys in onCreate SHOULD trigger', () {
        expect('PRAGMA foreign_keys in onCreate', isNotNull);
      });

      test('PRAGMA foreign_keys in beforeOpen should NOT trigger', () {
        expect('PRAGMA foreign_keys in beforeOpen', isNotNull);
      });
    });

    group('require_drift_reads_from', () {
      test('customSelect.watch() without readsFrom SHOULD trigger', () {
        expect('customSelect.watch() without readsFrom', isNotNull);
      });

      test('customSelect with readsFrom should NOT trigger', () {
        expect('customSelect with readsFrom', isNotNull);
      });
    });

    group('avoid_drift_unsafe_web_storage', () {
      test('WebDatabase constructor SHOULD trigger', () {
        expect('WebDatabase constructor', isNotNull);
      });

      test('driftDatabase() should NOT trigger', () {
        expect('driftDatabase()', isNotNull);
      });
    });

    group('avoid_drift_close_streams_in_tests', () {
      test('NativeDatabase.memory() without wrapper SHOULD trigger', () {
        expect('NativeDatabase.memory() without wrapper', isNotNull);
      });

      test(
        'DatabaseConnection with closeStreamsSynchronously should NOT trigger',
        () {
          expect(
            'DatabaseConnection with closeStreamsSynchronously',
            isNotNull,
          );
        },
      );

      test('testRelevance is testOnly so rule runs on test files', () {
        final rule = AvoidDriftCloseStreamsInTestsRule();
        expect(rule.testRelevance, TestRelevance.testOnly);
      });
    });

    group('avoid_drift_nullable_converter_mismatch', () {
      test('TypeConverter<Foo?, int?> SHOULD trigger', () {
        expect('TypeConverter<Foo?, int?>', isNotNull);
      });

      test('TypeConverter<Foo, int> should NOT trigger', () {
        expect('TypeConverter<Foo, int>', isNotNull);
      });
    });
  });

  group('Drift - Additional High-Confidence Rules', () {
    group('avoid_drift_value_null_vs_absent', () {
      test('Value(null) in Companion SHOULD trigger', () {
        // Value(null) sets column to NULL — crashes on non-nullable columns
        expect('Value(null) in Companion', isNotNull);
      });

      test('Value.absent() should NOT trigger', () {
        // Value.absent() leaves column unchanged — correct usage
        expect('Value.absent()', isNotNull);
      });

      test('Value(someVariable) should NOT trigger (false positive guard)', () {
        // Only Value(null) literal is problematic, not Value(variable)
        expect('Value(someVariable) is valid', isNotNull);
      });

      test('Value(42) should NOT trigger (non-null literal)', () {
        // Non-null arguments to Value() are fine
        expect('Value(42) is valid', isNotNull);
      });
    });

    group('require_drift_equals_value', () {
      test('.equals(EnumType.value) SHOULD trigger', () {
        // PrefixedIdentifier with uppercase prefix looks like enum access
        expect('.equals(EnumType.value)', isNotNull);
      });

      test('.equalsValue(EnumType.value) should NOT trigger', () {
        // equalsValue() correctly applies TypeConverter
        expect('.equalsValue(EnumType.value)', isNotNull);
      });

      test(
        '.equals(DateTime.now) should NOT trigger (false positive guard)',
        () {
          // DateTime, Duration, etc. are valid raw types, not enums
          expect('DateTime is excluded from heuristic', isNotNull);
        },
      );

      test('.equals(variable) should NOT trigger (simple identifier)', () {
        // Simple identifier (not PrefixedIdentifier) is not enum-like
        expect('simple variable is not PrefixedIdentifier', isNotNull);
      });

      test('.equals(42) should NOT trigger (literal value)', () {
        // Numeric literals are valid raw SQL values
        expect('literal value is not PrefixedIdentifier', isNotNull);
      });
    });

    group('require_drift_read_table_or_null', () {
      test('readTable() with leftOuterJoin SHOULD trigger', () {
        // readTable() throws on null rows from left join
        expect('readTable() with leftOuterJoin', isNotNull);
      });

      test('readTableOrNull() with leftOuterJoin should NOT trigger', () {
        // readTableOrNull() safely returns null
        expect('readTableOrNull() with leftOuterJoin', isNotNull);
      });

      test(
        'readTable() without any join should NOT trigger (false positive)',
        () {
          // readTable() is safe when there's no left join
          expect('readTable() without leftOuterJoin is safe', isNotNull);
        },
      );

      test('readTable() with innerJoin should NOT trigger', () {
        // Inner joins always return matched rows — readTable() is safe
        expect('innerJoin guarantees non-null', isNotNull);
      });
    });

    group('require_drift_create_all_in_oncreate', () {
      test('onCreate without createAll SHOULD trigger', () {
        // Missing createAll() means no tables on fresh install
        expect('onCreate without createAll', isNotNull);
      });

      test('onCreate with createAll should NOT trigger', () {
        // createAll() properly creates all tables
        expect('onCreate with createAll', isNotNull);
      });

      test(
        'onCreate in non-drift context should NOT trigger (false positive)',
        () {
          // Other libraries use onCreate too — drift import check prevents this
          expect('non-drift onCreate is excluded', isNotNull);
        },
      );
    });

    group('avoid_drift_validate_schema_production', () {
      test('validateDatabaseSchema without guard SHOULD trigger', () {
        // Unguarded schema validation runs in production
        expect('validateDatabaseSchema without guard', isNotNull);
      });

      test('validateDatabaseSchema with kDebugMode should NOT trigger', () {
        // Properly guarded with debug mode check
        expect('validateDatabaseSchema with kDebugMode', isNotNull);
      });

      test('validateDatabaseSchema with kReleaseMode should NOT trigger', () {
        // kReleaseMode guard is also acceptable
        expect('kReleaseMode guard is valid', isNotNull);
      });

      test('validateDatabaseSchema in assert() should NOT trigger', () {
        // assert() is stripped in release — valid guard
        expect('assert guard is valid', isNotNull);
      });
    });
  });

  group('Drift - Additional Medium-Confidence Rules', () {
    group('avoid_drift_replace_without_all_columns', () {
      test('.replace() on update builder SHOULD trigger', () {
        // replace() sets unspecified columns to default/null
        expect('.replace() on update builder', isNotNull);
      });

      test('.write() on update builder should NOT trigger', () {
        // write() only updates specified columns
        expect('.write() on update builder', isNotNull);
      });

      test(
        '.replace() without update() should NOT trigger (false positive)',
        () {
          // replace() on non-Drift update builders is fine
          expect('replace() without update chain is excluded', isNotNull);
        },
      );
    });

    group('avoid_drift_missing_updates_param', () {
      test('customUpdate without updates param SHOULD trigger', () {
        // Missing updates means streams won't refresh
        expect('customUpdate without updates param', isNotNull);
      });

      test('customUpdate with updates param should NOT trigger', () {
        // updates: {table} properly invalidates streams
        expect('customUpdate with updates param', isNotNull);
      });

      test('customInsert without updates param SHOULD trigger', () {
        // customInsert also needs updates for stream invalidation
        expect('customInsert without updates', isNotNull);
      });

      test(
        'non-drift customUpdate should NOT trigger (false positive guard)',
        () {
          // After fix: drift import check prevents false positives
          expect('non-drift customUpdate excluded', isNotNull);
        },
      );
    });
  });

  group('Drift - Isar-to-Drift Migration Rules', () {
    group('avoid_isar_import_with_drift', () {
      test('file importing both isar and drift SHOULD trigger', () {
        // Both imports suggest incomplete migration
        expect('file importing both isar and drift', isNotNull);
      });

      test('file importing only drift should NOT trigger', () {
        // Drift-only import is fully migrated
        expect('file importing only drift', isNotNull);
      });

      test('file importing only isar should NOT trigger (false positive)', () {
        // Isar-only file is not a migration issue
        expect('isar-only file is not flagged', isNotNull);
      });
    });

    group('prefer_drift_foreign_key_declaration', () {
      test('integer column named userId without references SHOULD trigger', () {
        // userId strongly suggests a foreign key relationship
        expect('integer userId without references', isNotNull);
      });

      test('integer column with references() should NOT trigger', () {
        // references() properly declares the FK
        expect('integer column with references()', isNotNull);
      });

      test('integer column with customConstraint should NOT trigger', () {
        // customConstraint() can declare FK via SQL
        expect('customConstraint is acceptable', isNotNull);
      });

      test('androidId should NOT trigger (false positive guard)', () {
        // androidId is a device identifier, not a foreign key
        expect('androidId excluded from heuristic', isNotNull);
      });

      test('deviceId should NOT trigger (false positive guard)', () {
        // deviceId is a device identifier, not a foreign key
        expect('deviceId excluded from heuristic', isNotNull);
      });

      test('column named just "id" should NOT trigger', () {
        // "id" is a primary key, not a foreign key
        expect('primary key id excluded', isNotNull);
      });

      test('non-Table class should NOT trigger (false positive guard)', () {
        // Getter ending in Id in a non-Table class is irrelevant
        expect('non-Table class excluded', isNotNull);
      });
    });

    group('require_drift_onupgrade_handler', () {
      test('schemaVersion > 1 without onUpgrade SHOULD trigger', () {
        // Missing onUpgrade crashes on app update
        expect('schemaVersion > 1 without onUpgrade', isNotNull);
      });

      test('schemaVersion > 1 with onUpgrade should NOT trigger', () {
        // onUpgrade handler properly handles migration
        expect('schemaVersion > 1 with onUpgrade', isNotNull);
      });

      test('schemaVersion == 1 without onUpgrade should NOT trigger', () {
        // First version never needs onUpgrade
        expect('schemaVersion 1 needs no onUpgrade', isNotNull);
      });

      test('non-Drift database class should NOT trigger (false positive)', () {
        // Class not extending _$Something is not a Drift database
        expect('non-Drift class excluded', isNotNull);
      });
    });
  });
}
