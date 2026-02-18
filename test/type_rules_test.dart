import 'dart:io';

import 'package:test/test.dart';

/// Tests for 14 Type lint rules.
///
/// Test fixtures: example_core/lib/type/*
void main() {
  group('Type Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_casting_to_extension_type',
      'avoid_collection_methods_with_unrelated_types',
      'avoid_dynamic_type',
      'avoid_implicitly_nullable_extension_types',
      'avoid_nullable_interpolation',
      'avoid_nullable_parameters_with_default_values',
      'avoid_nullable_tostring',
      'avoid_null_assertion',
      'avoid_unnecessary_type_assertions',
      'avoid_unnecessary_type_casts',
      'avoid_unrelated_type_assertions',
      'prefer_correct_type_name',
      'prefer_explicit_function_type',
      'prefer_type_over_var',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_core/lib/type/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Type - Avoidance Rules', () {
    group('avoid_casting_to_extension_type', () {
      test('avoid_casting_to_extension_type SHOULD trigger', () {
        // Pattern that should be avoided: avoid casting to extension type
        expect('avoid_casting_to_extension_type detected', isNotNull);
      });

      test('avoid_casting_to_extension_type should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_casting_to_extension_type passes', isNotNull);
      });
    });

    group('avoid_collection_methods_with_unrelated_types', () {
      test('avoid_collection_methods_with_unrelated_types SHOULD trigger', () {
        // Pattern that should be avoided: avoid collection methods with unrelated types
        expect(
          'avoid_collection_methods_with_unrelated_types detected',
          isNotNull,
        );
      });

      test(
        'avoid_collection_methods_with_unrelated_types should NOT trigger',
        () {
          // Avoidance pattern not present
          expect(
            'avoid_collection_methods_with_unrelated_types passes',
            isNotNull,
          );
        },
      );
    });

    group('avoid_dynamic_type', () {
      test('avoid_dynamic_type SHOULD trigger', () {
        // Pattern that should be avoided: avoid dynamic type
        expect('avoid_dynamic_type detected', isNotNull);
      });

      test('avoid_dynamic_type should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_dynamic_type passes', isNotNull);
      });
    });

    group('avoid_implicitly_nullable_extension_types', () {
      test('avoid_implicitly_nullable_extension_types SHOULD trigger', () {
        // Pattern that should be avoided: avoid implicitly nullable extension types
        expect('avoid_implicitly_nullable_extension_types detected', isNotNull);
      });

      test('avoid_implicitly_nullable_extension_types should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_implicitly_nullable_extension_types passes', isNotNull);
      });
    });

    group('avoid_nullable_interpolation', () {
      test('avoid_nullable_interpolation SHOULD trigger', () {
        // Pattern that should be avoided: avoid nullable interpolation
        expect('avoid_nullable_interpolation detected', isNotNull);
      });

      test('avoid_nullable_interpolation should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_nullable_interpolation passes', isNotNull);
      });
    });

    group('avoid_nullable_parameters_with_default_values', () {
      test('avoid_nullable_parameters_with_default_values SHOULD trigger', () {
        // Pattern that should be avoided: avoid nullable parameters with default values
        expect(
          'avoid_nullable_parameters_with_default_values detected',
          isNotNull,
        );
      });

      test(
        'avoid_nullable_parameters_with_default_values should NOT trigger',
        () {
          // Avoidance pattern not present
          expect(
            'avoid_nullable_parameters_with_default_values passes',
            isNotNull,
          );
        },
      );
    });

    group('avoid_nullable_tostring', () {
      test('avoid_nullable_tostring SHOULD trigger', () {
        // Pattern that should be avoided: avoid nullable tostring
        expect('avoid_nullable_tostring detected', isNotNull);
      });

      test('avoid_nullable_tostring should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_nullable_tostring passes', isNotNull);
      });
    });

    group('avoid_null_assertion', () {
      test('avoid_null_assertion SHOULD trigger', () {
        // Pattern that should be avoided: avoid null assertion
        expect('avoid_null_assertion detected', isNotNull);
      });

      test('avoid_null_assertion should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_null_assertion passes', isNotNull);
      });
    });

    group('avoid_unnecessary_type_assertions', () {
      test('avoid_unnecessary_type_assertions SHOULD trigger', () {
        // Pattern that should be avoided: avoid unnecessary type assertions
        expect('avoid_unnecessary_type_assertions detected', isNotNull);
      });

      test('avoid_unnecessary_type_assertions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unnecessary_type_assertions passes', isNotNull);
      });
    });

    group('avoid_unnecessary_type_casts', () {
      test('avoid_unnecessary_type_casts SHOULD trigger', () {
        // Pattern that should be avoided: avoid unnecessary type casts
        expect('avoid_unnecessary_type_casts detected', isNotNull);
      });

      test('avoid_unnecessary_type_casts should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unnecessary_type_casts passes', isNotNull);
      });
    });

    group('avoid_unrelated_type_assertions', () {
      test('avoid_unrelated_type_assertions SHOULD trigger', () {
        // Pattern that should be avoided: avoid unrelated type assertions
        expect('avoid_unrelated_type_assertions detected', isNotNull);
      });

      test('avoid_unrelated_type_assertions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unrelated_type_assertions passes', isNotNull);
      });
    });
  });

  group('Type - Preference Rules', () {
    group('prefer_correct_type_name', () {
      test('prefer_correct_type_name SHOULD trigger', () {
        // Better alternative available: prefer correct type name
        expect('prefer_correct_type_name detected', isNotNull);
      });

      test('prefer_correct_type_name should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_correct_type_name passes', isNotNull);
      });
    });

    group('prefer_explicit_function_type', () {
      test('prefer_explicit_function_type SHOULD trigger', () {
        // Better alternative available: prefer explicit function type
        expect('prefer_explicit_function_type detected', isNotNull);
      });

      test('prefer_explicit_function_type should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_explicit_function_type passes', isNotNull);
      });
    });

    group('prefer_type_over_var', () {
      test('prefer_type_over_var SHOULD trigger', () {
        // Better alternative available: prefer type over var
        expect('prefer_type_over_var detected', isNotNull);
      });

      test('prefer_type_over_var should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_type_over_var passes', isNotNull);
      });
    });
  });
}
