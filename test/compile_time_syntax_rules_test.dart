import 'package:saropa_lints/src/rules/architecture/compile_time_syntax_rules.dart';
import 'package:test/test.dart';

/// Tests for compile-time syntax rules (plan_additional_rules_21_through_30 subset).
void main() {
  group('Compile-time syntax rules - Rule Instantiation', () {
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
      'DuplicateConstructorRule',
      'duplicate_constructor',
      () => DuplicateConstructorRule(),
    );
    testRule(
      'ConflictingConstructorAndStaticMemberRule',
      'conflicting_constructor_and_static_member',
      () => ConflictingConstructorAndStaticMemberRule(),
    );
    testRule(
      'FieldInitializerRedirectingConstructorRule',
      'field_initializer_redirecting_constructor',
      () => FieldInitializerRedirectingConstructorRule(),
    );
    testRule(
      'InvalidSuperFormalParameterLocationRule',
      'invalid_super_formal_parameter_location',
      () => InvalidSuperFormalParameterLocationRule(),
    );
    testRule(
      'IllegalConcreteEnumMemberRule',
      'illegal_concrete_enum_member',
      () => IllegalConcreteEnumMemberRule(),
    );
    testRule(
      'InvalidLiteralAnnotationRule',
      'invalid_literal_annotation',
      () => InvalidLiteralAnnotationRule(),
    );
    testRule(
      'InvalidNonVirtualAnnotationRule',
      'invalid_non_virtual_annotation',
      () => InvalidNonVirtualAnnotationRule(),
    );
    testRule(
      'AbstractFieldInitializerRule',
      'abstract_field_initializer',
      () => AbstractFieldInitializerRule(),
    );
    testRule(
      'UndefinedEnumConstructorRule',
      'undefined_enum_constructor',
      () => UndefinedEnumConstructorRule(),
    );
  });
}
