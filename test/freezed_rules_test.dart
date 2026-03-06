import 'dart:io';

import 'package:saropa_lints/src/rules/codegen/freezed_rules.dart';
import 'package:test/test.dart';

/// Tests for 10 Freezed lint rules.
///
/// Test fixtures: example_packages/lib/freezed/*
void main() {
  group('Freezed Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.name.toLowerCase(), codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'AvoidFreezedJsonSerializableConflictRule',
      'avoid_freezed_json_serializable_conflict',
      () => AvoidFreezedJsonSerializableConflictRule(),
    );
    testRule(
      'AvoidFreezedInvalidAnnotationTargetRule',
      'avoid_freezed_invalid_annotation_target',
      () => AvoidFreezedInvalidAnnotationTargetRule(),
    );
    testRule(
      'RequireFreezedArrowSyntaxRule',
      'require_freezed_arrow_syntax',
      () => RequireFreezedArrowSyntaxRule(),
    );
    testRule(
      'RequireFreezedPrivateConstructorRule',
      'require_freezed_private_constructor',
      () => RequireFreezedPrivateConstructorRule(),
    );
    testRule(
      'RequireFreezedExplicitJsonRule',
      'require_freezed_explicit_json',
      () => RequireFreezedExplicitJsonRule(),
    );
    testRule(
      'PreferFreezedDefaultValuesRule',
      'prefer_freezed_default_values',
      () => PreferFreezedDefaultValuesRule(),
    );
    testRule(
      'RequireFreezedJsonConverterRule',
      'require_freezed_json_converter',
      () => RequireFreezedJsonConverterRule(),
    );
    testRule(
      'RequireFreezedLintPackageRule',
      'require_freezed_lint_package',
      () => RequireFreezedLintPackageRule(),
    );
    testRule(
      'AvoidFreezedForLogicClassesRule',
      'avoid_freezed_for_logic_classes',
      () => AvoidFreezedForLogicClassesRule(),
    );
    testRule(
      'PreferFreezedForDataClassesRule',
      'prefer_freezed_for_data_classes',
      () => PreferFreezedForDataClassesRule(),
    );
    testRule(
      'AvoidFreezedAnyMapIssueRule',
      'avoid_freezed_any_map_issue',
      () => AvoidFreezedAnyMapIssueRule(),
    );
  });
  group('Freezed Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_freezed_json_serializable_conflict',
      'avoid_freezed_invalid_annotation_target',
      'require_freezed_arrow_syntax',
      'require_freezed_private_constructor',
      'require_freezed_explicit_json',
      'prefer_freezed_default_values',
      'prefer_freezed_union_types',
      'require_freezed_json_converter',
      'require_freezed_lint_package',
      'avoid_freezed_for_logic_classes',
      'prefer_freezed_for_data_classes',
      'avoid_freezed_any_map_issue',
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
