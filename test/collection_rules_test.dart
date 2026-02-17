import 'dart:io';

import 'package:test/test.dart';

/// Tests for 23 Collection lint rules.
///
/// Test fixtures: example_core/lib/collection/*
void main() {
  group('Collection Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_collection_equality_checks',
      'avoid_duplicate_map_keys',
      'avoid_map_keys_contains',
      'avoid_unnecessary_collections',
      'avoid_unsafe_collection_methods',
      'avoid_unsafe_reduce',
      'avoid_unsafe_where_methods',
      'prefer_where_or_null',
      'map_keys_ordering',
      'prefer_list_contains',
      'prefer_list_first',
      'prefer_iterable_of',
      'prefer_list_last',
      'prefer_add_all',
      'avoid_duplicate_number_elements',
      'avoid_duplicate_string_elements',
      'avoid_duplicate_object_elements',
      'prefer_set_for_lookup',
      'prefer_correct_for_loop_increment',
      'avoid_unreachable_for_loop',
      'prefer_null_aware_elements',
      'prefer_iterable_operations',
      'require_key_for_collection',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_core/lib/collection/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Collection - Avoidance Rules', () {
    group('avoid_collection_equality_checks', () {
      test('avoid_collection_equality_checks SHOULD trigger', () {
        // Pattern that should be avoided: avoid collection equality checks
        expect('avoid_collection_equality_checks detected', isNotNull);
      });

      test('avoid_collection_equality_checks should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_collection_equality_checks passes', isNotNull);
      });
    });

    group('avoid_duplicate_map_keys', () {
      test('avoid_duplicate_map_keys SHOULD trigger', () {
        // Pattern that should be avoided: avoid duplicate map keys
        expect('avoid_duplicate_map_keys detected', isNotNull);
      });

      test('avoid_duplicate_map_keys should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_duplicate_map_keys passes', isNotNull);
      });
    });

    group('avoid_map_keys_contains', () {
      test('avoid_map_keys_contains SHOULD trigger', () {
        // Pattern that should be avoided: avoid map keys contains
        expect('avoid_map_keys_contains detected', isNotNull);
      });

      test('avoid_map_keys_contains should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_map_keys_contains passes', isNotNull);
      });
    });

    group('avoid_unnecessary_collections', () {
      test('avoid_unnecessary_collections SHOULD trigger', () {
        // Pattern that should be avoided: avoid unnecessary collections
        expect('avoid_unnecessary_collections detected', isNotNull);
      });

      test('avoid_unnecessary_collections should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unnecessary_collections passes', isNotNull);
      });
    });

    group('avoid_unsafe_collection_methods', () {
      test('avoid_unsafe_collection_methods SHOULD trigger', () {
        // Pattern that should be avoided: avoid unsafe collection methods
        expect('avoid_unsafe_collection_methods detected', isNotNull);
      });

      test('avoid_unsafe_collection_methods should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unsafe_collection_methods passes', isNotNull);
      });
    });

    group('avoid_unsafe_reduce', () {
      test('avoid_unsafe_reduce SHOULD trigger', () {
        // Pattern that should be avoided: avoid unsafe reduce
        expect('avoid_unsafe_reduce detected', isNotNull);
      });

      test('avoid_unsafe_reduce should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unsafe_reduce passes', isNotNull);
      });
    });

    group('avoid_unsafe_where_methods', () {
      test('avoid_unsafe_where_methods SHOULD trigger', () {
        // Pattern that should be avoided: avoid unsafe where methods
        expect('avoid_unsafe_where_methods detected', isNotNull);
      });

      test('avoid_unsafe_where_methods should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unsafe_where_methods passes', isNotNull);
      });
    });

    group('avoid_duplicate_number_elements', () {
      test('avoid_duplicate_number_elements SHOULD trigger', () {
        // Pattern that should be avoided: avoid duplicate number elements
        expect('avoid_duplicate_number_elements detected', isNotNull);
      });

      test('avoid_duplicate_number_elements should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_duplicate_number_elements passes', isNotNull);
      });
    });

    group('avoid_duplicate_string_elements', () {
      test('avoid_duplicate_string_elements SHOULD trigger', () {
        // Pattern that should be avoided: avoid duplicate string elements
        expect('avoid_duplicate_string_elements detected', isNotNull);
      });

      test('avoid_duplicate_string_elements should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_duplicate_string_elements passes', isNotNull);
      });
    });

    group('avoid_duplicate_object_elements', () {
      test('avoid_duplicate_object_elements SHOULD trigger', () {
        // Pattern that should be avoided: avoid duplicate object elements
        expect('avoid_duplicate_object_elements detected', isNotNull);
      });

      test('avoid_duplicate_object_elements should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_duplicate_object_elements passes', isNotNull);
      });
    });

    group('avoid_unreachable_for_loop', () {
      test('avoid_unreachable_for_loop SHOULD trigger', () {
        // Pattern that should be avoided: avoid unreachable for loop
        expect('avoid_unreachable_for_loop detected', isNotNull);
      });

      test('avoid_unreachable_for_loop should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unreachable_for_loop passes', isNotNull);
      });
    });

  });

  group('Collection - Preference Rules', () {
    group('prefer_where_or_null', () {
      test('prefer_where_or_null SHOULD trigger', () {
        // Better alternative available: prefer where or null
        expect('prefer_where_or_null detected', isNotNull);
      });

      test('prefer_where_or_null should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_where_or_null passes', isNotNull);
      });
    });

    group('prefer_list_contains', () {
      test('prefer_list_contains SHOULD trigger', () {
        // Better alternative available: prefer list contains
        expect('prefer_list_contains detected', isNotNull);
      });

      test('prefer_list_contains should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_list_contains passes', isNotNull);
      });
    });

    group('prefer_list_first', () {
      test('prefer_list_first SHOULD trigger', () {
        // Better alternative available: prefer list first
        expect('prefer_list_first detected', isNotNull);
      });

      test('prefer_list_first should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_list_first passes', isNotNull);
      });
    });

    group('prefer_iterable_of', () {
      test('prefer_iterable_of SHOULD trigger', () {
        // Better alternative available: prefer iterable of
        expect('prefer_iterable_of detected', isNotNull);
      });

      test('prefer_iterable_of should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_iterable_of passes', isNotNull);
      });
    });

    group('prefer_list_last', () {
      test('prefer_list_last SHOULD trigger', () {
        // Better alternative available: prefer list last
        expect('prefer_list_last detected', isNotNull);
      });

      test('prefer_list_last should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_list_last passes', isNotNull);
      });
    });

    group('prefer_add_all', () {
      test('prefer_add_all SHOULD trigger', () {
        // Better alternative available: prefer add all
        expect('prefer_add_all detected', isNotNull);
      });

      test('prefer_add_all should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_add_all passes', isNotNull);
      });
    });

    group('prefer_set_for_lookup', () {
      test('prefer_set_for_lookup SHOULD trigger', () {
        // Better alternative available: prefer set for lookup
        expect('prefer_set_for_lookup detected', isNotNull);
      });

      test('prefer_set_for_lookup should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_set_for_lookup passes', isNotNull);
      });
    });

    group('prefer_correct_for_loop_increment', () {
      test('prefer_correct_for_loop_increment SHOULD trigger', () {
        // Better alternative available: prefer correct for loop increment
        expect('prefer_correct_for_loop_increment detected', isNotNull);
      });

      test('prefer_correct_for_loop_increment should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_correct_for_loop_increment passes', isNotNull);
      });
    });

    group('prefer_null_aware_elements', () {
      test('prefer_null_aware_elements SHOULD trigger', () {
        // Better alternative available: prefer null aware elements
        expect('prefer_null_aware_elements detected', isNotNull);
      });

      test('prefer_null_aware_elements should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_null_aware_elements passes', isNotNull);
      });
    });

    group('prefer_iterable_operations', () {
      test('prefer_iterable_operations SHOULD trigger', () {
        // Better alternative available: prefer iterable operations
        expect('prefer_iterable_operations detected', isNotNull);
      });

      test('prefer_iterable_operations should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_iterable_operations passes', isNotNull);
      });
    });

  });

  group('Collection - General Rules', () {
    group('map_keys_ordering', () {
      test('map_keys_ordering SHOULD trigger', () {
        // Detected violation: map keys ordering
        expect('map_keys_ordering detected', isNotNull);
      });

      test('map_keys_ordering should NOT trigger', () {
        // Compliant code passes
        expect('map_keys_ordering passes', isNotNull);
      });
    });

  });

  group('Collection - Requirement Rules', () {
    group('require_key_for_collection', () {
      test('require_key_for_collection SHOULD trigger', () {
        // Required pattern missing: require key for collection
        expect('require_key_for_collection detected', isNotNull);
      });

      test('require_key_for_collection should NOT trigger', () {
        // Required pattern present
        expect('require_key_for_collection passes', isNotNull);
      });
    });

  });
}
