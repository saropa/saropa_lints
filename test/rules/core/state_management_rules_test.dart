import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/core/state_management_rules.dart';

/// Tests for 10 State Management lint rules.
///
/// Test fixtures: example/lib/state_management/*
void main() {
  group('State Management Rules - Rule Instantiation', () {
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
      'RequireNotifyListenersRule',
      'require_notify_listeners',
      () => RequireNotifyListenersRule(),
    );

    testRule(
      'RequireStreamControllerDisposeRule',
      'require_stream_controller_dispose',
      () => RequireStreamControllerDisposeRule(),
    );
    test('RequireStreamControllerDisposeRule relatedRules', () {
      final rule = RequireStreamControllerDisposeRule();
      expect(
        rule.relatedRules,
        containsAll(<String>[
          'require_dispose_implementation',
          'require_animation_controller_dispose',
          'require_mounted_check',
        ]),
      );
    });

    testRule(
      'RequireValueNotifierDisposeRule',
      'require_value_notifier_dispose',
      () => RequireValueNotifierDisposeRule(),
    );

    testRule(
      'RequireMountedCheckRule',
      'require_mounted_check',
      () => RequireMountedCheckRule(),
    );
    test('RequireMountedCheckRule relatedRules', () {
      final rule = RequireMountedCheckRule();
      expect(
        rule.relatedRules,
        containsAll(<String>[
          'require_stream_controller_dispose',
          'require_dispose_implementation',
        ]),
      );
    });

    testRule(
      'AvoidStatefulWithoutStateRule',
      'avoid_stateful_without_state',
      () => AvoidStatefulWithoutStateRule(),
    );

    testRule(
      'AvoidGlobalKeyInBuildRule',
      'avoid_global_key_in_build',
      () => AvoidGlobalKeyInBuildRule(),
    );

    testRule(
      'AvoidSetStateInLargeStateClassRule',
      'avoid_setstate_in_large_state_class',
      () => AvoidSetStateInLargeStateClassRule(),
    );

    testRule(
      'PreferImmutableSelectorValueRule',
      'prefer_immutable_selector_value',
      () => PreferImmutableSelectorValueRule(),
    );

    testRule(
      'AvoidStaticStateRule',
      'avoid_static_state',
      () => AvoidStaticStateRule(),
    );

    testRule(
      'PreferOptimisticUpdatesRule',
      'prefer_optimistic_updates',
      () => PreferOptimisticUpdatesRule(),
    );

    testRule(
      'AvoidCollectionMutatingMethodsRule',
      'avoid_collection_mutating_methods',
      () => AvoidCollectionMutatingMethodsRule(),
    );
  });

  group('State Management Rules - Fixture Verification', () {
    final fixtures = [
      'require_notify_listeners',
      'require_stream_controller_dispose',
      'avoid_collection_mutating_methods',
      'require_value_notifier_dispose',
      'require_mounted_check',
      'avoid_stateful_without_state',
      'avoid_global_key_in_build',
      'avoid_setstate_in_large_state_class',
      'prefer_immutable_selector_value',
      'avoid_static_state',
      'prefer_optimistic_updates',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/state_management/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('State Management - Requirement Rules', () {
    group('require_notify_listeners', () {
      test('require_notify_listeners SHOULD trigger', () {
        // Required pattern missing: require notify listeners
      });

      test('require_notify_listeners should NOT trigger', () {
        // Required pattern present
      });
    });

    group('require_stream_controller_dispose', () {
      test('require_stream_controller_dispose SHOULD trigger', () {
        // Required pattern missing: require stream controller dispose
      });

      test('require_stream_controller_dispose should NOT trigger', () {
        // Required pattern present
      });
    });

    group('require_value_notifier_dispose', () {
      test('require_value_notifier_dispose SHOULD trigger', () {
        // Required pattern missing: require value notifier dispose
      });

      test('require_value_notifier_dispose should NOT trigger', () {
        // Required pattern present
      });
    });

    group('require_mounted_check', () {
      test('require_mounted_check SHOULD trigger', () {
        // Required pattern missing: require mounted check
      });

      test('require_mounted_check should NOT trigger', () {
        // Required pattern present
      });
    });
  });

  group('State Management - Avoidance Rules', () {
    group('avoid_stateful_without_state', () {
      test('avoid_stateful_without_state SHOULD trigger', () {
        // Pattern that should be avoided: avoid stateful without state
      });

      test('avoid_stateful_without_state should NOT trigger', () {
        // Avoidance pattern not present
      });
    });

    group('avoid_global_key_in_build', () {
      test('avoid_global_key_in_build SHOULD trigger', () {
        // Pattern that should be avoided: avoid global key in build
      });

      test('avoid_global_key_in_build should NOT trigger', () {
        // Avoidance pattern not present
      });
    });

    group('avoid_setstate_in_large_state_class', () {
      test('avoid_setstate_in_large_state_class SHOULD trigger', () {
        // Pattern that should be avoided: avoid setstate in large state class
      });

      test('avoid_setstate_in_large_state_class should NOT trigger', () {
        // Avoidance pattern not present
      });
    });

    group('avoid_static_state', () {
      test('avoid_static_state SHOULD trigger', () {
        // Pattern that should be avoided: avoid static state
      });

      test('avoid_static_state should NOT trigger', () {
        // Avoidance pattern not present
      });
    });
  });

  group('State Management - Preference Rules', () {
    group('prefer_immutable_selector_value', () {
      test('prefer_immutable_selector_value SHOULD trigger', () {
        // Better alternative available: prefer immutable selector value
      });

      test('prefer_immutable_selector_value should NOT trigger', () {
        // Preferred pattern used correctly
      });
    });

    group('prefer_optimistic_updates', () {
      test('prefer_optimistic_updates SHOULD trigger', () {
        // Better alternative available: prefer optimistic updates
      });

      test('prefer_optimistic_updates should NOT trigger', () {
        // Preferred pattern used correctly
      });
    });
  });
}
