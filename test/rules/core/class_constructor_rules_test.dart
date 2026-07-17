import 'dart:io';

import 'package:saropa_lints/src/rules/core/class_constructor_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 21 Class Constructor lint rules.
///
/// Test fixtures: example/lib/class_constructor/*
void main() {
  group('Class Constructor Rules - Rule Instantiation', () {
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
    final fixtureDir = Directory('example/lib/class_constructor');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/class_constructor/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
