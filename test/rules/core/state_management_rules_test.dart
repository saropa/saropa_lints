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
    final fixtureDir = Directory('example/lib/state_management');

    // Auto-discover fixtures from disk so new files are verified

    // automatically — no manual list to maintain.

    final fixtures =
        fixtureDir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('_fixture.dart'))
            .map((name) => name.replaceAll('_fixture.dart', ''))
            .toList()
          ..sort();

    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/state_management/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
