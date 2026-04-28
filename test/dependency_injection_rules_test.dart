import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/architecture/dependency_injection_rules.dart';

/// Tests for 15 Dependency Injection lint rules.
///
/// Test fixtures: example/lib/dependency_injection/*
void main() {
  group('Dependency Injection Rules - Rule Instantiation', () {
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
      'AvoidServiceLocatorInWidgetsRule',
      'avoid_service_locator_in_widgets',
      () => AvoidServiceLocatorInWidgetsRule(),
    );

    testRule(
      'AvoidTooManyDependenciesRule',
      'avoid_too_many_dependencies',
      () => AvoidTooManyDependenciesRule(),
    );

    testRule(
      'AvoidInternalDependencyCreationRule',
      'avoid_internal_dependency_creation',
      () => AvoidInternalDependencyCreationRule(),
    );

    testRule(
      'PreferAbstractDependenciesRule',
      'prefer_abstract_dependencies',
      () => PreferAbstractDependenciesRule(),
    );

    testRule(
      'AvoidSingletonForScopedDependenciesRule',
      'avoid_singleton_for_scoped_dependencies',
      () => AvoidSingletonForScopedDependenciesRule(),
    );

    testRule(
      'AvoidCircularDiDependenciesRule',
      'avoid_circular_di_dependencies',
      () => AvoidCircularDiDependenciesRule(),
    );

    testRule(
      'PreferNullObjectPatternRule',
      'prefer_null_object_pattern',
      () => PreferNullObjectPatternRule(),
    );

    testRule(
      'RequireTypedDiRegistrationRule',
      'require_typed_di_registration',
      () => RequireTypedDiRegistrationRule(),
    );

    testRule(
      'AvoidFunctionsInRegisterSingletonRule',
      'avoid_functions_in_register_singleton',
      () => AvoidFunctionsInRegisterSingletonRule(),
    );

    testRule(
      'RequireDefaultConfigRule',
      'require_default_config',
      () => RequireDefaultConfigRule(),
    );

    testRule(
      'PreferConstructorInjectionRule',
      'prefer_constructor_injection',
      () => PreferConstructorInjectionRule(),
    );

    testRule(
      'RequireDiScopeAwarenessRule',
      'require_di_scope_awareness',
      () => RequireDiScopeAwarenessRule(),
    );

    testRule(
      'AvoidDiInWidgetsRule',
      'avoid_di_in_widgets',
      () => AvoidDiInWidgetsRule(),
    );

    testRule(
      'PreferAbstractionInjectionRule',
      'prefer_abstraction_injection',
      () => PreferAbstractionInjectionRule(),
    );

    testRule(
      'PreferLazySingletonRegistrationRule',
      'prefer_lazy_singleton_registration',
      () => PreferLazySingletonRegistrationRule(),
    );
  });

  group('Dependency Injection Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_service_locator_in_widgets',
      'avoid_too_many_dependencies',
      'avoid_internal_dependency_creation',
      'prefer_abstract_dependencies',
      'avoid_singleton_for_scoped_dependencies',
      'avoid_circular_di_dependencies',
      'prefer_null_object_pattern',
      'require_typed_di_registration',
      'avoid_functions_in_register_singleton',
      'require_default_config',
      'prefer_constructor_injection',
      'require_di_scope_awareness',
      'avoid_di_in_widgets',
      'prefer_abstraction_injection',
      'prefer_lazy_singleton_registration',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/dependency_injection/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
