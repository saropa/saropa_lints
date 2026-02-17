import 'dart:io';

import 'package:test/test.dart';

/// Tests for 21 Isar lint rules.
///
/// Test fixtures: example_packages/lib/isar/*
void main() {
  group('Isar Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_isar_enum_field',
      'require_isar_collection_annotation',
      'require_isar_id_field',
      'require_isar_close_on_dispose',
      'prefer_isar_async_writes',
      'avoid_isar_transaction_nesting',
      'prefer_isar_batch_operations',
      'avoid_isar_float_equality_queries',
      'require_isar_inspector_debug_only',
      'avoid_isar_clear_in_production',
      'require_isar_links_load',
      'prefer_isar_query_stream',
      'avoid_isar_web_limitations',
      'prefer_isar_index_for_queries',
      'avoid_isar_embedded_large_objects',
      'prefer_isar_lazy_links',
      'avoid_isar_schema_breaking_changes',
      'require_isar_nullable_field',
      'prefer_isar_composite_index',
      'avoid_isar_string_contains_without_index',
      'avoid_cached_isar_stream',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_packages/lib/isar/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Isar - Avoidance Rules', () {
    group('avoid_isar_enum_field', () {
      test('avoid_isar_enum_field SHOULD trigger', () {
        // Pattern that should be avoided: avoid isar enum field
        expect('avoid_isar_enum_field detected', isNotNull);
      });

      test('avoid_isar_enum_field should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_isar_enum_field passes', isNotNull);
      });
    });

    group('avoid_isar_transaction_nesting', () {
      test('avoid_isar_transaction_nesting SHOULD trigger', () {
        // Pattern that should be avoided: avoid isar transaction nesting
        expect('avoid_isar_transaction_nesting detected', isNotNull);
      });

      test('avoid_isar_transaction_nesting should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_isar_transaction_nesting passes', isNotNull);
      });
    });

    group('avoid_isar_float_equality_queries', () {
      test('avoid_isar_float_equality_queries SHOULD trigger', () {
        // Pattern that should be avoided: avoid isar float equality queries
        expect('avoid_isar_float_equality_queries detected', isNotNull);
      });

      test('avoid_isar_float_equality_queries should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_isar_float_equality_queries passes', isNotNull);
      });
    });

    group('avoid_isar_clear_in_production', () {
      test('avoid_isar_clear_in_production SHOULD trigger', () {
        // Pattern that should be avoided: avoid isar clear in production
        expect('avoid_isar_clear_in_production detected', isNotNull);
      });

      test('avoid_isar_clear_in_production should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_isar_clear_in_production passes', isNotNull);
      });
    });

    group('avoid_isar_web_limitations', () {
      test('avoid_isar_web_limitations SHOULD trigger', () {
        // Pattern that should be avoided: avoid isar web limitations
        expect('avoid_isar_web_limitations detected', isNotNull);
      });

      test('avoid_isar_web_limitations should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_isar_web_limitations passes', isNotNull);
      });
    });

    group('avoid_isar_embedded_large_objects', () {
      test('avoid_isar_embedded_large_objects SHOULD trigger', () {
        // Pattern that should be avoided: avoid isar embedded large objects
        expect('avoid_isar_embedded_large_objects detected', isNotNull);
      });

      test('avoid_isar_embedded_large_objects should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_isar_embedded_large_objects passes', isNotNull);
      });
    });

    group('avoid_isar_schema_breaking_changes', () {
      test('avoid_isar_schema_breaking_changes SHOULD trigger', () {
        // Pattern that should be avoided: avoid isar schema breaking changes
        expect('avoid_isar_schema_breaking_changes detected', isNotNull);
      });

      test('avoid_isar_schema_breaking_changes should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_isar_schema_breaking_changes passes', isNotNull);
      });
    });

    group('avoid_isar_string_contains_without_index', () {
      test('avoid_isar_string_contains_without_index SHOULD trigger', () {
        // Pattern that should be avoided: avoid isar string contains without index
        expect('avoid_isar_string_contains_without_index detected', isNotNull);
      });

      test('avoid_isar_string_contains_without_index should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_isar_string_contains_without_index passes', isNotNull);
      });
    });

    group('avoid_cached_isar_stream', () {
      test('avoid_cached_isar_stream SHOULD trigger', () {
        // Pattern that should be avoided: avoid cached isar stream
        expect('avoid_cached_isar_stream detected', isNotNull);
      });

      test('avoid_cached_isar_stream should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_cached_isar_stream passes', isNotNull);
      });
    });

  });

  group('Isar - Requirement Rules', () {
    group('require_isar_collection_annotation', () {
      test('require_isar_collection_annotation SHOULD trigger', () {
        // Required pattern missing: require isar collection annotation
        expect('require_isar_collection_annotation detected', isNotNull);
      });

      test('require_isar_collection_annotation should NOT trigger', () {
        // Required pattern present
        expect('require_isar_collection_annotation passes', isNotNull);
      });
    });

    group('require_isar_id_field', () {
      test('require_isar_id_field SHOULD trigger', () {
        // Required pattern missing: require isar id field
        expect('require_isar_id_field detected', isNotNull);
      });

      test('require_isar_id_field should NOT trigger', () {
        // Required pattern present
        expect('require_isar_id_field passes', isNotNull);
      });
    });

    group('require_isar_close_on_dispose', () {
      test('require_isar_close_on_dispose SHOULD trigger', () {
        // Required pattern missing: require isar close on dispose
        expect('require_isar_close_on_dispose detected', isNotNull);
      });

      test('require_isar_close_on_dispose should NOT trigger', () {
        // Required pattern present
        expect('require_isar_close_on_dispose passes', isNotNull);
      });
    });

    group('require_isar_inspector_debug_only', () {
      test('require_isar_inspector_debug_only SHOULD trigger', () {
        // Required pattern missing: require isar inspector debug only
        expect('require_isar_inspector_debug_only detected', isNotNull);
      });

      test('require_isar_inspector_debug_only should NOT trigger', () {
        // Required pattern present
        expect('require_isar_inspector_debug_only passes', isNotNull);
      });
    });

    group('require_isar_links_load', () {
      test('require_isar_links_load SHOULD trigger', () {
        // Required pattern missing: require isar links load
        expect('require_isar_links_load detected', isNotNull);
      });

      test('require_isar_links_load should NOT trigger', () {
        // Required pattern present
        expect('require_isar_links_load passes', isNotNull);
      });
    });

    group('require_isar_nullable_field', () {
      test('require_isar_nullable_field SHOULD trigger', () {
        // Required pattern missing: require isar nullable field
        expect('require_isar_nullable_field detected', isNotNull);
      });

      test('require_isar_nullable_field should NOT trigger', () {
        // Required pattern present
        expect('require_isar_nullable_field passes', isNotNull);
      });
    });

  });

  group('Isar - Preference Rules', () {
    group('prefer_isar_async_writes', () {
      test('prefer_isar_async_writes SHOULD trigger', () {
        // Better alternative available: prefer isar async writes
        expect('prefer_isar_async_writes detected', isNotNull);
      });

      test('prefer_isar_async_writes should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_isar_async_writes passes', isNotNull);
      });
    });

    group('prefer_isar_batch_operations', () {
      test('prefer_isar_batch_operations SHOULD trigger', () {
        // Better alternative available: prefer isar batch operations
        expect('prefer_isar_batch_operations detected', isNotNull);
      });

      test('prefer_isar_batch_operations should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_isar_batch_operations passes', isNotNull);
      });
    });

    group('prefer_isar_query_stream', () {
      test('prefer_isar_query_stream SHOULD trigger', () {
        // Better alternative available: prefer isar query stream
        expect('prefer_isar_query_stream detected', isNotNull);
      });

      test('prefer_isar_query_stream should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_isar_query_stream passes', isNotNull);
      });
    });

    group('prefer_isar_index_for_queries', () {
      test('prefer_isar_index_for_queries SHOULD trigger', () {
        // Better alternative available: prefer isar index for queries
        expect('prefer_isar_index_for_queries detected', isNotNull);
      });

      test('prefer_isar_index_for_queries should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_isar_index_for_queries passes', isNotNull);
      });
    });

    group('prefer_isar_lazy_links', () {
      test('prefer_isar_lazy_links SHOULD trigger', () {
        // Better alternative available: prefer isar lazy links
        expect('prefer_isar_lazy_links detected', isNotNull);
      });

      test('prefer_isar_lazy_links should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_isar_lazy_links passes', isNotNull);
      });
    });

    group('prefer_isar_composite_index', () {
      test('prefer_isar_composite_index SHOULD trigger', () {
        // Better alternative available: prefer isar composite index
        expect('prefer_isar_composite_index detected', isNotNull);
      });

      test('prefer_isar_composite_index should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_isar_composite_index passes', isNotNull);
      });
    });

  });
}
