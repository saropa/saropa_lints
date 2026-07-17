import 'dart:io';

import 'package:saropa_lints/src/rules/packages/riverpod_rules.dart';
import 'package:test/test.dart';

/// Tests for 37 Riverpod lint rules.
///
/// These rules cover ref.read/watch usage, provider lifecycle, notifier
/// patterns, async value handling, auto-dispose, and architectural patterns.
///
/// Test fixtures: example_packages/lib/riverpod/*
void main() {
  group('Riverpod Rules - Rule Instantiation', () {
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
      'AvoidRefReadInsideBuildRule',
      'avoid_ref_read_inside_build',
      () => AvoidRefReadInsideBuildRule(),
    );
    testRule(
      'AvoidRiverpodStateNotifierRule',
      'avoid_riverpod_state_notifier',
      () => AvoidRiverpodStateNotifierRule(),
    );
    testRule(
      'AvoidRefWatchOutsideBuildRule',
      'avoid_ref_watch_outside_build',
      () => AvoidRefWatchOutsideBuildRule(),
    );
    testRule(
      'AvoidRefInsideStateDisposeRule',
      'avoid_ref_inside_state_dispose',
      () => AvoidRefInsideStateDisposeRule(),
    );
    testRule(
      'UseRefReadSynchronouslyRule',
      'use_ref_read_synchronously',
      () => UseRefReadSynchronouslyRule(),
    );
    testRule(
      'UseRefAndStateSynchronouslyRule',
      'use_ref_and_state_synchronously',
      () => UseRefAndStateSynchronouslyRule(),
    );
    testRule(
      'AvoidAssigningNotifiersRule',
      'avoid_assigning_notifiers',
      () => AvoidAssigningNotifiersRule(),
    );
    testRule(
      'AvoidNotifierConstructorsRule',
      'avoid_notifier_constructors',
      () => AvoidNotifierConstructorsRule(),
    );
    testRule(
      'PreferImmutableProviderArgumentsRule',
      'prefer_immutable_provider_arguments',
      () => PreferImmutableProviderArgumentsRule(),
    );
    testRule(
      'AvoidUnnecessaryConsumerWidgetsRule',
      'avoid_unnecessary_consumer_widgets',
      () => AvoidUnnecessaryConsumerWidgetsRule(),
    );
    testRule(
      'AvoidNullableAsyncValuePatternRule',
      'avoid_nullable_async_value_pattern',
      () => AvoidNullableAsyncValuePatternRule(),
    );
    testRule(
      'RequireRiverpodErrorHandlingRule',
      'require_riverpod_error_handling',
      () => RequireRiverpodErrorHandlingRule(),
    );
    testRule(
      'AvoidRiverpodStateMutationRule',
      'avoid_riverpod_state_mutation',
      () => AvoidRiverpodStateMutationRule(),
    );
    testRule(
      'PreferRiverpodSelectRule',
      'prefer_riverpod_select',
      () => PreferRiverpodSelectRule(),
    );
    testRule(
      'RequireFlutterRiverpodPackageRule',
      'require_flutter_riverpod_package',
      () => RequireFlutterRiverpodPackageRule(),
    );
    testRule(
      'PreferRiverpodAutoDisposeRule',
      'prefer_riverpod_auto_dispose',
      () => PreferRiverpodAutoDisposeRule(),
    );
    testRule(
      'PreferRiverpodFamilyForParamsRule',
      'prefer_riverpod_family_for_params',
      () => PreferRiverpodFamilyForParamsRule(),
    );
    testRule(
      'AvoidGlobalRiverpodProvidersRule',
      'avoid_global_riverpod_providers',
      () => AvoidGlobalRiverpodProvidersRule(),
    );
    testRule(
      'PreferConsumerWidgetRule',
      'prefer_consumer_widget',
      () => PreferConsumerWidgetRule(),
    );
    testRule(
      'RequireAutoDisposeRule',
      'require_auto_dispose',
      () => RequireAutoDisposeRule(),
    );
    testRule(
      'AvoidRiverpodStringProviderNameRule',
      'avoid_riverpod_string_provider_name',
      () => AvoidRiverpodStringProviderNameRule(),
    );
    testRule(
      'AvoidRefInBuildBodyRule',
      'avoid_ref_in_build_body',
      () => AvoidRefInBuildBodyRule(),
    );
    testRule(
      'AvoidRefInDisposeRule',
      'avoid_ref_in_dispose',
      () => AvoidRefInDisposeRule(),
    );
    testRule(
      'RequireProviderScopeRule',
      'require_provider_scope',
      () => RequireProviderScopeRule(),
    );
    testRule(
      'PreferSelectForPartialRule',
      'prefer_select_for_partial',
      () => PreferSelectForPartialRule(),
    );
    testRule(
      'PreferFamilyForParamsRule',
      'prefer_family_for_params',
      () => PreferFamilyForParamsRule(),
    );
    testRule(
      'PreferRefWatchOverReadRule',
      'prefer_ref_watch_over_read',
      () => PreferRefWatchOverReadRule(),
    );
    testRule(
      'AvoidCircularProviderDepsRule',
      'avoid_circular_provider_deps',
      () => AvoidCircularProviderDepsRule(),
    );
    testRule(
      'RequireErrorHandlingInAsyncRule',
      'require_error_handling_in_async',
      () => RequireErrorHandlingInAsyncRule(),
    );
    testRule(
      'PreferNotifierOverStateRule',
      'prefer_notifier_over_state',
      () => PreferNotifierOverStateRule(),
    );
    testRule(
      'RequireRiverpodLintRule',
      'require_riverpod_lint',
      () => RequireRiverpodLintRule(),
    );
    testRule(
      'AvoidListenInAsyncRule',
      'avoid_listen_in_async',
      () => AvoidListenInAsyncRule(),
    );
    testRule(
      'RequireAsyncValueOrderRule',
      'require_async_value_order',
      () => RequireAsyncValueOrderRule(),
    );
    testRule(
      'PreferSelectorRule',
      'prefer_context_selector',
      () => PreferSelectorRule(),
    );
    testRule(
      'AvoidRiverpodNotifierInBuildRule',
      'avoid_riverpod_notifier_in_build',
      () => AvoidRiverpodNotifierInBuildRule(),
    );
    testRule(
      'RequireRiverpodAsyncValueGuardRule',
      'require_riverpod_async_value_guard',
      () => RequireRiverpodAsyncValueGuardRule(),
    );
    testRule(
      'RequireFlutterRiverpodNotRiverpodRule',
      'require_flutter_riverpod_not_riverpod',
      () => RequireFlutterRiverpodNotRiverpodRule(),
    );
    testRule(
      'AvoidRiverpodNavigationRule',
      'avoid_riverpod_navigation',
      () => AvoidRiverpodNavigationRule(),
    );
    testRule(
      'AvoidRiverpodForNetworkOnlyRule',
      'avoid_riverpod_for_network_only',
      () => AvoidRiverpodForNetworkOnlyRule(),
    );
  });
  group('Riverpod Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/riverpod');

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
      test('\$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/riverpod/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
