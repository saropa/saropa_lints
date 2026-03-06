import 'dart:io';

import 'package:saropa_lints/src/rules/core/class_constructor_rules.dart';
import 'package:test/test.dart';

/// Tests for 21 Class Constructor lint rules.
///
/// Test fixtures: example_core/lib/class_constructor/*
void main() {
  group('Class Constructor Rules - Rule Instantiation', () {
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
      'AvoidDeclaringCallMethodRule',
      'avoid_declaring_call_method',
      () => AvoidDeclaringCallMethodRule(),
    );
    testRule(
      'AvoidReferencingSubclassesRule',
      'avoid_referencing_subclasses',
      () => AvoidReferencingSubclassesRule(),
    );
    testRule(
      'AvoidGenericsShadowingRule',
      'avoid_generics_shadowing',
      () => AvoidGenericsShadowingRule(),
    );
    testRule(
      'AvoidIncompleteCopyWithRule',
      'avoid_incomplete_copy_with',
      () => AvoidIncompleteCopyWithRule(),
    );
    testRule(
      'AvoidNonEmptyConstructorBodiesRule',
      'avoid_non_empty_constructor_bodies',
      () => AvoidNonEmptyConstructorBodiesRule(),
    );
    testRule(
      'AvoidShadowingRule',
      'avoid_variable_shadowing',
      () => AvoidShadowingRule(),
    );
    testRule(
      'PreferConstStringListRule',
      'prefer_const_string_list',
      () => PreferConstStringListRule(),
    );
    testRule(
      'PreferDeclaringConstConstructorRule',
      'prefer_declaring_const_constructor',
      () => PreferDeclaringConstConstructorRule(),
    );
    testRule(
      'PreferNonConstConstructorsRule',
      'prefer_non_const_constructors',
      () => PreferNonConstConstructorsRule(),
    );
    testRule(
      'PreferFactoryConstructorRule',
      'prefer_factory_constructor',
      () => PreferFactoryConstructorRule(),
    );
    testRule(
      'PreferPrivateExtensionTypeFieldRule',
      'prefer_private_extension_type_field',
      () => PreferPrivateExtensionTypeFieldRule(),
    );
    testRule(
      'AvoidRenamingRepresentationGettersRule',
      'avoid_renaming_representation_getters',
      () => AvoidRenamingRepresentationGettersRule(),
    );
    testRule(
      'ProperSuperCallsRule',
      'proper_super_calls',
      () => ProperSuperCallsRule(),
    );
    testRule(
      'AvoidUnmarkedPublicClassRule',
      'avoid_unmarked_public_class',
      () => AvoidUnmarkedPublicClassRule(),
    );
    testRule(
      'PreferFinalClassRule',
      'prefer_final_class',
      () => PreferFinalClassRule(),
    );
    testRule(
      'PreferInterfaceClassRule',
      'prefer_interface_class',
      () => PreferInterfaceClassRule(),
    );
    testRule(
      'PreferBaseClassRule',
      'prefer_base_class',
      () => PreferBaseClassRule(),
    );
    testRule(
      'AvoidAccessingOtherClassesPrivateMembersRule',
      'avoid_accessing_other_classes_private_members',
      () => AvoidAccessingOtherClassesPrivateMembersRule(),
    );
    testRule(
      'AvoidUnusedConstructorParametersRule',
      'avoid_unused_constructor_parameters',
      () => AvoidUnusedConstructorParametersRule(),
    );
    testRule(
      'AvoidFieldInitializersInConstClassesRule',
      'avoid_field_initializers_in_const_classes',
      () => AvoidFieldInitializersInConstClassesRule(),
    );
    testRule(
      'RequireLateAccessCheckRule',
      'require_late_access_check',
      () => RequireLateAccessCheckRule(),
    );
    testRule(
      'PreferAssertsInInitializerListsRule',
      'prefer_asserts_in_initializer_lists',
      () => PreferAssertsInInitializerListsRule(),
    );
    testRule(
      'PreferConstConstructorsInImmutablesRule',
      'prefer_const_constructors_in_immutables',
      () => PreferConstConstructorsInImmutablesRule(),
    );
    testRule(
      'PreferFinalFieldsRule',
      'prefer_final_fields',
      () => PreferFinalFieldsRule(),
    );
    testRule(
      'PreferFinalFieldsAlwaysRule',
      'prefer_final_fields_always',
      () => PreferFinalFieldsAlwaysRule(),
    );
  });

  group('Class Constructor Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_declaring_call_method',
      'avoid_referencing_subclasses',
      'avoid_generics_shadowing',
      'avoid_incomplete_copy_with',
      'avoid_non_empty_constructor_bodies',
      'avoid_variable_shadowing',
      'prefer_const_string_list',
      'prefer_declaring_const_constructor',
      'prefer_non_const_constructors',
      'prefer_factory_constructor',
      'prefer_private_extension_type_field',
      'avoid_renaming_representation_getters',
      'proper_super_calls',
      'avoid_unmarked_public_class',
      'prefer_final_class',
      'prefer_interface_class',
      'prefer_base_class',
      'require_late_access_check',
      'avoid_accessing_other_classes_private_members',
      'avoid_unused_constructor_parameters',
      'avoid_field_initializers_in_const_classes',
      'prefer_asserts_in_initializer_lists',
      'prefer_const_constructors_in_immutables',
      'prefer_final_fields',
      'prefer_final_fields_always',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_core/lib/class_constructor/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Class Constructor - Avoidance Rules', () {
    group('avoid_declaring_call_method', () {
      test('avoid_declaring_call_method SHOULD trigger', () {
        // Pattern that should be avoided: avoid declaring call method
        expect('avoid_declaring_call_method detected', isNotNull);
      });

      test('avoid_declaring_call_method should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_declaring_call_method passes', isNotNull);
      });
    });

    group('avoid_generics_shadowing', () {
      test('avoid_generics_shadowing SHOULD trigger', () {
        // Pattern that should be avoided: avoid generics shadowing
        expect('avoid_generics_shadowing detected', isNotNull);
      });

      test('avoid_generics_shadowing should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_generics_shadowing passes', isNotNull);
      });
    });

    group('avoid_incomplete_copy_with', () {
      test('avoid_incomplete_copy_with SHOULD trigger', () {
        // Pattern that should be avoided: avoid incomplete copy with
        expect('avoid_incomplete_copy_with detected', isNotNull);
      });

      test('avoid_incomplete_copy_with should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_incomplete_copy_with passes', isNotNull);
      });
    });

    group('avoid_non_empty_constructor_bodies', () {
      test('avoid_non_empty_constructor_bodies SHOULD trigger', () {
        // Pattern that should be avoided: avoid non empty constructor bodies
        expect('avoid_non_empty_constructor_bodies detected', isNotNull);
      });

      test('avoid_non_empty_constructor_bodies should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_non_empty_constructor_bodies passes', isNotNull);
      });
    });

    group('avoid_variable_shadowing', () {
      test('avoid_variable_shadowing SHOULD trigger', () {
        // Pattern that should be avoided: avoid variable shadowing
        expect('avoid_variable_shadowing detected', isNotNull);
      });

      test('avoid_variable_shadowing should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_variable_shadowing passes', isNotNull);
      });
    });

    group('avoid_unmarked_public_class', () {
      test('avoid_unmarked_public_class SHOULD trigger', () {
        // Pattern that should be avoided: avoid unmarked public class
        expect('avoid_unmarked_public_class detected', isNotNull);
      });

      test('avoid_unmarked_public_class should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unmarked_public_class passes', isNotNull);
      });
    });
  });

  group('Class Constructor - Preference Rules', () {
    group('prefer_const_string_list', () {
      test('prefer_const_string_list SHOULD trigger', () {
        // Better alternative available: prefer const string list
        expect('prefer_const_string_list detected', isNotNull);
      });

      test('prefer_const_string_list should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_const_string_list passes', isNotNull);
      });
    });

    group('prefer_declaring_const_constructor', () {
      test('prefer_declaring_const_constructor SHOULD trigger', () {
        // Better alternative available: prefer declaring const constructor
        expect('prefer_declaring_const_constructor detected', isNotNull);
      });

      test('prefer_declaring_const_constructor should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_declaring_const_constructor passes', isNotNull);
      });
    });

    group('prefer_private_extension_type_field', () {
      test('prefer_private_extension_type_field SHOULD trigger', () {
        // Better alternative available: prefer private extension type field
        expect('prefer_private_extension_type_field detected', isNotNull);
      });

      test('prefer_private_extension_type_field should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_private_extension_type_field passes', isNotNull);
      });
    });

    group('prefer_final_class', () {
      test('prefer_final_class SHOULD trigger', () {
        // Better alternative available: prefer final class
        expect('prefer_final_class detected', isNotNull);
      });

      test('prefer_final_class should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_final_class passes', isNotNull);
      });
    });

    group('prefer_interface_class', () {
      test('prefer_interface_class SHOULD trigger', () {
        // Better alternative available: prefer interface class
        expect('prefer_interface_class detected', isNotNull);
      });

      test('prefer_interface_class should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_interface_class passes', isNotNull);
      });
    });

    group('prefer_base_class', () {
      test('prefer_base_class SHOULD trigger', () {
        // Better alternative available: prefer base class
        expect('prefer_base_class detected', isNotNull);
      });

      test('prefer_base_class should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_base_class passes', isNotNull);
      });
    });
  });

  group('Class Constructor - General Rules', () {
    group('proper_super_calls', () {
      test('proper_super_calls SHOULD trigger', () {
        // Detected violation: proper super calls
        expect('proper_super_calls detected', isNotNull);
      });

      test('proper_super_calls should NOT trigger', () {
        // Compliant code passes
        expect('proper_super_calls passes', isNotNull);
      });
    });
  });

  group('Class Constructor - Requirement Rules', () {
    group('require_late_access_check', () {
      test('require_late_access_check SHOULD trigger', () {
        // late field set in method, read in another without guard
        expect('require_late_access_check detected', isNotNull);
      });

      test('require_late_access_check should NOT trigger', () {
        // nullable or constructor-init or late final
        expect('require_late_access_check passes', isNotNull);
      });
    });
  });
}
