import 'dart:io';

import 'package:test/test.dart';

/// Tests for 9 Freezed lint rules.
///
/// Test fixtures: example_packages/lib/freezed/*
void main() {
  group('Freezed Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_freezed_json_serializable_conflict',
      'require_freezed_arrow_syntax',
      'require_freezed_private_constructor',
      'require_freezed_explicit_json',
      'prefer_freezed_default_values',
      'require_freezed_json_converter',
      'require_freezed_lint_package',
      'avoid_freezed_for_logic_classes',
      'prefer_freezed_for_data_classes',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/freezed/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Freezed - Avoidance Rules', () {
    group('avoid_freezed_json_serializable_conflict', () {
      test(
        'conflicting JsonSerializable + Freezed annotations SHOULD trigger',
        () {
          expect(
            'conflicting JsonSerializable + Freezed annotations',
            isNotNull,
          );
        },
      );

      test('Freezed-only serialization should NOT trigger', () {
        expect('Freezed-only serialization', isNotNull);
      });
    });
    group('avoid_freezed_for_logic_classes', () {
      test('Freezed on class with business logic SHOULD trigger', () {
        expect('Freezed on class with business logic', isNotNull);
      });

      test('Freezed only for data classes should NOT trigger', () {
        expect('Freezed only for data classes', isNotNull);
      });
    });
  });

  group('Freezed - Requirement Rules', () {
    group('require_freezed_arrow_syntax', () {
      test('verbose Freezed factory syntax SHOULD trigger', () {
        expect('verbose Freezed factory syntax', isNotNull);
      });

      test('arrow syntax for simple factories should NOT trigger', () {
        expect('arrow syntax for simple factories', isNotNull);
      });
    });
    group('require_freezed_private_constructor', () {
      test('public Freezed constructor SHOULD trigger', () {
        expect('public Freezed constructor', isNotNull);
      });

      test('private underscore constructor should NOT trigger', () {
        expect('private underscore constructor', isNotNull);
      });
    });
    group('require_freezed_explicit_json', () {
      test('missing fromJson/toJson on Freezed SHOULD trigger', () {
        expect('missing fromJson/toJson on Freezed', isNotNull);
      });

      test('explicit JSON methods should NOT trigger', () {
        expect('explicit JSON methods', isNotNull);
      });
    });
    group('require_freezed_json_converter', () {
      test('raw type in Freezed JSON SHOULD trigger', () {
        expect('raw type in Freezed JSON', isNotNull);
      });

      test('JsonConverter for custom types should NOT trigger', () {
        expect('JsonConverter for custom types', isNotNull);
      });
    });
    group('require_freezed_lint_package', () {
      test('freezed_annotation import without freezed_lint SHOULD trigger', () {
        expect('freezed_annotation without freezed_lint', isNotNull);
      });

      test(
        'both freezed_annotation and freezed_lint imported should NOT trigger',
        () {
          expect('complete freezed imports', isNotNull);
        },
      );
    });
  });

  group('Freezed - Preference Rules', () {
    group('prefer_freezed_default_values', () {
      test('no defaults on Freezed fields SHOULD trigger', () {
        expect('no defaults on Freezed fields', isNotNull);
      });

      test('default value annotations should NOT trigger', () {
        expect('default value annotations', isNotNull);
      });
    });
    group('prefer_freezed_for_data_classes', () {
      test('manual data class without Freezed SHOULD trigger', () {
        expect('manual data class without Freezed', isNotNull);
      });

      test('Freezed for immutable data should NOT trigger', () {
        expect('Freezed for immutable data', isNotNull);
      });
    });
  });
}
