import 'dart:io';

import 'package:saropa_lints/src/rules/packages/bloc_rules.dart';
import 'package:test/test.dart';

/// Tests for 52 Bloc and Cubit lint rules.
///
/// These rules cover BLoC event handling, state management, provider patterns,
/// architectural best practices, naming conventions, and common anti-patterns.
///
/// Test fixtures: example_packages/lib/bloc/*
// Bloc/Cubit and flutter_bloc patterns; large rule instantiation table.
void main() {
  group('Bloc Rules - Rule Instantiation', () {
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
      'AvoidBlocEventInConstructorRule',
      'avoid_bloc_event_in_constructor',
      () => AvoidBlocEventInConstructorRule(),
    );
    testRule(
      'AvoidBlocMapEventToStateRule',
      'avoid_bloc_map_event_to_state',
      () => AvoidBlocMapEventToStateRule(),
    );
    testRule(
      'RequireBlocCloseRule',
      'require_bloc_close',
      () => RequireBlocCloseRule(),
    );
    testRule(
      'RequireImmutableBlocStateRule',
      'require_immutable_bloc_state',
      () => RequireImmutableBlocStateRule(),
    );
    testRule(
      'PreferCubitForSimpleRule',
      'prefer_cubit_for_simple',
      () => PreferCubitForSimpleRule(),
    );
    testRule('AvoidCubitsRule', 'avoid_cubit_usage', () => AvoidCubitsRule());
    testRule(
      'RequireBlocObserverRule',
      'require_bloc_observer',
      () => RequireBlocObserverRule(),
    );
    testRule(
      'AvoidBlocEventMutationRule',
      'avoid_bloc_event_mutation',
      () => AvoidBlocEventMutationRule(),
    );
    testRule(
      'PreferCopyWithForStateRule',
      'prefer_copy_with_for_state',
      () => PreferCopyWithForStateRule(),
    );
    testRule(
      'AvoidBlocListenInBuildRule',
      'avoid_bloc_listen_in_build',
      () => AvoidBlocListenInBuildRule(),
    );
    testRule(
      'RequireInitialStateRule',
      'require_initial_state',
      () => RequireInitialStateRule(),
    );
    testRule(
      'RequireErrorStateRule',
      'require_error_state',
      () => RequireErrorStateRule(),
    );
    testRule(
      'AvoidBlocInBlocRule',
      'avoid_bloc_in_bloc',
      () => AvoidBlocInBlocRule(),
    );
    testRule(
      'PreferSealedEventsRule',
      'prefer_sealed_events',
      () => PreferSealedEventsRule(),
    );
    testRule(
      'RequireBlocTransformerRule',
      'require_bloc_transformer',
      () => RequireBlocTransformerRule(),
    );
    testRule(
      'AvoidLongEventHandlersRule',
      'avoid_long_event_handlers',
      () => AvoidLongEventHandlersRule(),
    );
    testRule(
      'PreferMultiBlocProviderRule',
      'prefer_multi_bloc_provider',
      () => PreferMultiBlocProviderRule(),
    );
    testRule(
      'AvoidInstantiatingInBlocValueProviderRule',
      'avoid_instantiating_in_bloc_value_provider',
      () => AvoidInstantiatingInBlocValueProviderRule(),
    );
    testRule(
      'AvoidExistingInstancesInBlocProviderRule',
      'avoid_existing_instances_in_bloc_provider',
      () => AvoidExistingInstancesInBlocProviderRule(),
    );
    testRule(
      'PreferCorrectBlocProviderRule',
      'prefer_correct_bloc_provider',
      () => PreferCorrectBlocProviderRule(),
    );
    testRule(
      'CheckIsNotClosedAfterAsyncGapRule',
      'check_is_not_closed_after_async_gap',
      () => CheckIsNotClosedAfterAsyncGapRule(),
    );
    testRule(
      'AvoidDuplicateBlocEventHandlersRule',
      'avoid_duplicate_bloc_event_handlers',
      () => AvoidDuplicateBlocEventHandlersRule(),
    );
    testRule(
      'PreferImmutableBlocEventsRule',
      'prefer_immutable_bloc_events',
      () => PreferImmutableBlocEventsRule(),
    );
    testRule(
      'PreferImmutableBlocStateRule',
      'prefer_immutable_bloc_state',
      () => PreferImmutableBlocStateRule(),
    );
    testRule(
      'PreferSealedBlocEventsRule',
      'prefer_sealed_bloc_events',
      () => PreferSealedBlocEventsRule(),
    );
    testRule(
      'PreferSealedBlocStateRule',
      'prefer_sealed_bloc_state',
      () => PreferSealedBlocStateRule(),
    );
    testRule(
      'PreferBlocEventSuffixRule',
      'prefer_bloc_event_suffix',
      () => PreferBlocEventSuffixRule(),
    );
    testRule(
      'PreferBlocStateSuffixRule',
      'prefer_bloc_state_suffix',
      () => PreferBlocStateSuffixRule(),
    );
    testRule(
      'AvoidYieldInOnEventRule',
      'avoid_yield_in_on_event',
      () => AvoidYieldInOnEventRule(),
    );
    testRule(
      'EmitNewBlocStateInstancesRule',
      'emit_new_bloc_state_instances',
      () => EmitNewBlocStateInstancesRule(),
    );
    testRule(
      'AvoidBlocPublicFieldsRule',
      'avoid_bloc_public_fields',
      () => AvoidBlocPublicFieldsRule(),
    );
    testRule(
      'AvoidBlocPublicMethodsRule',
      'avoid_bloc_public_methods',
      () => AvoidBlocPublicMethodsRule(),
    );
    testRule(
      'RequireBlocSelectorRule',
      'require_bloc_selector',
      () => RequireBlocSelectorRule(),
    );
    testRule(
      'AvoidBlocEmitAfterCloseRule',
      'avoid_bloc_emit_after_close',
      () => AvoidBlocEmitAfterCloseRule(),
    );
    testRule(
      'AvoidBlocStateMutationRule',
      'avoid_bloc_state_mutation',
      () => AvoidBlocStateMutationRule(),
    );
    testRule(
      'RequireBlocInitialStateRule',
      'require_bloc_initial_state',
      () => RequireBlocInitialStateRule(),
    );
    testRule(
      'RequireBlocLoadingStateRule',
      'require_bloc_loading_state',
      () => RequireBlocLoadingStateRule(),
    );
    testRule(
      'RequireBlocErrorStateRule',
      'require_bloc_error_state',
      () => RequireBlocErrorStateRule(),
    );
    testRule(
      'RequireBlocManualDisposeRule',
      'require_bloc_manual_dispose',
      () => RequireBlocManualDisposeRule(),
    );
    testRule(
      'PreferCubitForSimpleStateRule',
      'prefer_cubit_for_simple_state',
      () => PreferCubitForSimpleStateRule(),
    );
    test('AvoidCubitsRule conflictingRules', () {
      final rule = AvoidCubitsRule();
      expect(rule.conflictingRules, contains('prefer_cubit_for_simple_state'));
    });
    test('PreferCubitForSimpleStateRule conflictingRules', () {
      final rule = PreferCubitForSimpleStateRule();
      expect(rule.conflictingRules, contains('avoid_cubit_usage'));
    });
    test('PreferCubitForSimpleStateRule supersedesRules', () {
      final rule = PreferCubitForSimpleStateRule();
      expect(rule.supersedesRules, contains('prefer_cubit_for_simple'));
    });
    testRule(
      'PreferBlocListenerForSideEffectsRule',
      'prefer_bloc_listener_for_side_effects',
      () => PreferBlocListenerForSideEffectsRule(),
    );
    testRule(
      'RequireBlocConsumerWhenBothRule',
      'require_bloc_consumer_when_both',
      () => RequireBlocConsumerWhenBothRule(),
    );
    testRule(
      'AvoidBlocContextDependencyRule',
      'avoid_bloc_context_dependency',
      () => AvoidBlocContextDependencyRule(),
    );
    testRule(
      'AvoidBlocBusinessLogicInUiRule',
      'avoid_bloc_business_logic_in_ui',
      () => AvoidBlocBusinessLogicInUiRule(),
    );
    testRule(
      'RequireBlocEventSealedRule',
      'require_bloc_event_sealed',
      () => RequireBlocEventSealedRule(),
    );
    testRule(
      'RequireBlocRepositoryAbstractionRule',
      'require_bloc_repository_abstraction',
      () => RequireBlocRepositoryAbstractionRule(),
    );
    testRule(
      'PreferBlocTransformRule',
      'prefer_bloc_transform',
      () => PreferBlocTransformRule(),
    );
    testRule(
      'AvoidPassingBlocToBlocRule',
      'avoid_passing_bloc_to_bloc',
      () => AvoidPassingBlocToBlocRule(),
    );
    testRule(
      'AvoidPassingBuildContextToBlocsRule',
      'avoid_passing_build_context_to_blocs',
      () => AvoidPassingBuildContextToBlocsRule(),
    );
    testRule(
      'AvoidReturningValueFromCubitMethodsRule',
      'avoid_returning_value_from_cubit_methods',
      () => AvoidReturningValueFromCubitMethodsRule(),
    );
    testRule(
      'RequireBlocRepositoryInjectionRule',
      'require_bloc_repository_injection',
      () => RequireBlocRepositoryInjectionRule(),
    );
    testRule(
      'PreferBlocHydrationRule',
      'prefer_bloc_hydration',
      () => PreferBlocHydrationRule(),
    );
    testRule(
      'AvoidLargeBlocRule',
      'avoid_large_bloc',
      () => AvoidLargeBlocRule(),
    );
    testRule(
      'AvoidOverengineeredBlocStatesRule',
      'avoid_overengineered_bloc_states',
      () => AvoidOverengineeredBlocStatesRule(),
    );
  });
  group('Bloc Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_bloc_business_logic_in_ui',
      'avoid_bloc_context_dependency',
      'avoid_cubit_usage',
      'avoid_bloc_emit_after_close',
      'avoid_bloc_event_in_constructor',
      'avoid_bloc_event_mutation',
      'avoid_bloc_in_bloc',
      'avoid_bloc_listen_in_build',
      'avoid_bloc_public_fields',
      'avoid_bloc_public_methods',
      'avoid_bloc_state_mutation',
      'avoid_duplicate_bloc_event_handlers',
      'avoid_overengineered_bloc_states',
      'emit_new_bloc_state_instances',
      'prefer_bloc_event_suffix',
      'prefer_bloc_extensions',
      'prefer_bloc_hydration',
      'prefer_bloc_listener_for_side_effects',
      'prefer_bloc_state_suffix',
      'prefer_immutable_bloc_events',
      'prefer_immutable_bloc_state',
      'prefer_sealed_bloc_events',
      'prefer_sealed_bloc_state',
      'require_bloc_close',
      'require_bloc_consumer_when_both',
      'require_bloc_error_state',
      'require_bloc_initial_state',
      'require_bloc_loading_state',
      'require_bloc_manual_dispose',
      'require_bloc_observer',
      'require_bloc_selector',
      'require_bloc_transformer',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_packages/lib/bloc/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture checks while migrating to analyzer-backed behavior tests.
}
