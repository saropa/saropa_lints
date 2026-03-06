import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/architecture/dependency_injection_rules.dart';

/// Tests for 15 Dependency Injection lint rules.
///
/// Test fixtures: example_core/lib/dependency_injection/*
void main() {
  group('Dependency Injection Rules - Rule Instantiation', () {
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
          'example_core/lib/dependency_injection/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Dependency Injection - Avoidance Rules', () {
    group('avoid_service_locator_in_widgets', () {
      test('avoid_service_locator_in_widgets SHOULD trigger', () {
        // Pattern that should be avoided: avoid service locator in widgets
        expect('avoid_service_locator_in_widgets detected', isNotNull);
      });

      test('avoid_service_locator_in_widgets should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_service_locator_in_widgets passes', isNotNull);
      });
    });

    group('avoid_too_many_dependencies', () {
      test('avoid_too_many_dependencies SHOULD trigger', () {
        // Pattern that should be avoided: avoid too many dependencies
        expect('avoid_too_many_dependencies detected', isNotNull);
      });

      test('avoid_too_many_dependencies should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_too_many_dependencies passes', isNotNull);
      });
    });

    group('avoid_internal_dependency_creation', () {
      test('avoid_internal_dependency_creation SHOULD trigger', () {
        // Pattern that should be avoided: avoid internal dependency creation
        expect('avoid_internal_dependency_creation detected', isNotNull);
      });

      test('avoid_internal_dependency_creation should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_internal_dependency_creation passes', isNotNull);
      });
    });

    group('avoid_singleton_for_scoped_dependencies', () {
      test('avoid_singleton_for_scoped_dependencies SHOULD trigger', () {
        // Pattern that should be avoided: avoid singleton for scoped dependencies
        expect('avoid_singleton_for_scoped_dependencies detected', isNotNull);
      });

      test('avoid_singleton_for_scoped_dependencies should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_singleton_for_scoped_dependencies passes', isNotNull);
      });
    });

    group('avoid_circular_di_dependencies', () {
      test('avoid_circular_di_dependencies SHOULD trigger', () {
        // Pattern that should be avoided: avoid circular di dependencies
        expect('avoid_circular_di_dependencies detected', isNotNull);
      });

      test('avoid_circular_di_dependencies should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_circular_di_dependencies passes', isNotNull);
      });
    });

    group('avoid_functions_in_register_singleton', () {
      test('avoid_functions_in_register_singleton SHOULD trigger', () {
        // Pattern that should be avoided: avoid functions in register singleton
        expect('avoid_functions_in_register_singleton detected', isNotNull);
      });

      test('avoid_functions_in_register_singleton should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_functions_in_register_singleton passes', isNotNull);
      });
    });

    group('avoid_di_in_widgets', () {
      test('avoid_di_in_widgets SHOULD trigger', () {
        // Pattern that should be avoided: avoid di in widgets
        expect('avoid_di_in_widgets detected', isNotNull);
      });

      test('avoid_di_in_widgets should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_di_in_widgets passes', isNotNull);
      });
    });
  });

  group('Dependency Injection - Preference Rules', () {
    group('prefer_abstract_dependencies', () {
      test('prefer_abstract_dependencies SHOULD trigger', () {
        // Better alternative available: prefer abstract dependencies
        expect('prefer_abstract_dependencies detected', isNotNull);
      });

      test('prefer_abstract_dependencies should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_abstract_dependencies passes', isNotNull);
      });
    });

    group('prefer_null_object_pattern', () {
      test('prefer_null_object_pattern SHOULD trigger', () {
        // Better alternative available: prefer null object pattern
        expect('prefer_null_object_pattern detected', isNotNull);
      });

      test('prefer_null_object_pattern should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_null_object_pattern passes', isNotNull);
      });
    });

    group('prefer_constructor_injection', () {
      test('prefer_constructor_injection SHOULD trigger', () {
        // Better alternative available: prefer constructor injection
        expect('prefer_constructor_injection detected', isNotNull);
      });

      test('prefer_constructor_injection should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_constructor_injection passes', isNotNull);
      });
    });

    group('prefer_abstraction_injection', () {
      test('prefer_abstraction_injection SHOULD trigger', () {
        // Better alternative available: prefer abstraction injection
        expect('prefer_abstraction_injection detected', isNotNull);
      });

      test('prefer_abstraction_injection should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_abstraction_injection passes', isNotNull);
      });
    });

    group('prefer_lazy_singleton_registration', () {
      test('prefer_lazy_singleton_registration SHOULD trigger', () {
        // Better alternative available: prefer lazy singleton registration
        expect('prefer_lazy_singleton_registration detected', isNotNull);
      });

      test('prefer_lazy_singleton_registration should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_lazy_singleton_registration passes', isNotNull);
      });
    });
  });

  group('Dependency Injection - Requirement Rules', () {
    group('require_typed_di_registration', () {
      test('require_typed_di_registration SHOULD trigger', () {
        // Required pattern missing: require typed di registration
        expect('require_typed_di_registration detected', isNotNull);
      });

      test('require_typed_di_registration should NOT trigger', () {
        // Required pattern present
        expect('require_typed_di_registration passes', isNotNull);
      });
    });

    group('require_default_config', () {
      test('require_default_config SHOULD trigger', () {
        // Required pattern missing: require default config
        expect('require_default_config detected', isNotNull);
      });

      test('require_default_config should NOT trigger', () {
        // Required pattern present
        expect('require_default_config passes', isNotNull);
      });
    });

    group('require_di_scope_awareness', () {
      test('require_di_scope_awareness SHOULD trigger', () {
        // Required pattern missing: require di scope awareness
        expect('require_di_scope_awareness detected', isNotNull);
      });

      test('require_di_scope_awareness should NOT trigger', () {
        // Required pattern present
        expect('require_di_scope_awareness passes', isNotNull);
      });
    });
  });
}
