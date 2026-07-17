import 'dart:io';

import 'package:saropa_lints/src/rules/widget/widget_lifecycle_rules.dart';
import 'package:test/test.dart';

/// Tests for 36 Widget Lifecycle lint rules.
///
/// Test fixtures: example/lib/widget_lifecycle/*
void main() {
  group('Widget Lifecycle Rules - Rule Instantiation', () {
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
      'AvoidContextInInitStateDisposeRule',
      'avoid_context_in_initstate_dispose',
      () => AvoidContextInInitStateDisposeRule(),
    );
    testRule(
      'AvoidEmptySetStateRule',
      'avoid_empty_setstate',
      () => AvoidEmptySetStateRule(),
    );
    testRule(
      'AvoidLateContextRule',
      'avoid_late_context',
      () => AvoidLateContextRule(),
    );
    testRule(
      'AvoidMountedInSetStateRule',
      'avoid_mounted_in_setstate',
      () => AvoidMountedInSetStateRule(),
    );
    testRule(
      'AvoidStateConstructorsRule',
      'avoid_state_constructors',
      () => AvoidStateConstructorsRule(),
    );
    testRule(
      'AvoidStatelessWidgetInitializedFieldsRule',
      'avoid_stateless_widget_initialized_fields',
      () => AvoidStatelessWidgetInitializedFieldsRule(),
    );
    testRule(
      'AvoidUnnecessarySetStateRule',
      'avoid_unnecessary_setstate',
      () => AvoidUnnecessarySetStateRule(),
    );
    testRule(
      'RequireInitStateIdempotentRule',
      'require_init_state_idempotent',
      () => RequireInitStateIdempotentRule(),
    );
    testRule(
      'AvoidUnnecessaryStatefulWidgetsRule',
      'avoid_unnecessary_stateful_widgets',
      () => AvoidUnnecessaryStatefulWidgetsRule(),
    );
    testRule(
      'AvoidUnremovableCallbacksInListenersRule',
      'avoid_unremovable_callbacks_in_listeners',
      () => AvoidUnremovableCallbacksInListenersRule(),
    );
    testRule(
      'AvoidUnsafeSetStateRule',
      'avoid_unsafe_setstate',
      () => AvoidUnsafeSetStateRule(),
    );
    testRule(
      'RequireDisposeRule',
      'require_field_dispose',
      () => RequireDisposeRule(),
    );
    testRule(
      'RequireTimerCancellationRule',
      'require_timer_cancellation',
      () => RequireTimerCancellationRule(),
    );
    testRule(
      'NullifyAfterDisposeRule',
      'nullify_after_dispose',
      () => NullifyAfterDisposeRule(),
    );
    testRule(
      'UseSetStateSynchronouslyRule',
      'use_setstate_synchronously',
      () => UseSetStateSynchronouslyRule(),
    );
    testRule(
      'AlwaysRemoveListenerRule',
      'always_remove_listener',
      () => AlwaysRemoveListenerRule(),
    );
    testRule(
      'RequireAnimationDisposalRule',
      'require_animation_disposal',
      () => RequireAnimationDisposalRule(),
    );
    testRule(
      'AvoidScaffoldMessengerAfterAwaitRule',
      'avoid_scaffold_messenger_after_await',
      () => AvoidScaffoldMessengerAfterAwaitRule(),
    );
    testRule(
      'AvoidBuildContextInProvidersRule',
      'avoid_build_context_in_providers',
      () => AvoidBuildContextInProvidersRule(),
    );
    testRule(
      'PreferWidgetStateMixinRule',
      'prefer_widget_state_mixin',
      () => PreferWidgetStateMixinRule(),
    );
    testRule(
      'AvoidInheritedWidgetInInitStateRule',
      'avoid_inherited_widget_in_initstate',
      () => AvoidInheritedWidgetInInitStateRule(),
    );
    testRule(
      'AvoidRecursiveWidgetCallsRule',
      'avoid_recursive_widget_calls',
      () => AvoidRecursiveWidgetCallsRule(),
    );
    testRule(
      'AvoidUndisposedInstancesRule',
      'avoid_undisposed_instances',
      () => AvoidUndisposedInstancesRule(),
    );
    testRule(
      'AvoidUnnecessaryOverridesInStateRule',
      'avoid_unnecessary_overrides_in_state',
      () => AvoidUnnecessaryOverridesInStateRule(),
    );
    testRule(
      'DisposeFieldsRule',
      'dispose_widget_fields',
      () => DisposeFieldsRule(),
    );
    testRule(
      'PassExistingFutureToFutureBuilderRule',
      'pass_existing_future_to_future_builder',
      () => PassExistingFutureToFutureBuilderRule(),
    );
    testRule(
      'PassExistingStreamToStreamBuilderRule',
      'pass_existing_stream_to_stream_builder',
      () => PassExistingStreamToStreamBuilderRule(),
    );
    testRule(
      'RequireScrollControllerDisposeRule',
      'require_scroll_controller_dispose',
      () => RequireScrollControllerDisposeRule(),
    );
    testRule(
      'RequireFocusNodeDisposeRule',
      'require_focus_node_dispose',
      () => RequireFocusNodeDisposeRule(),
    );
    testRule(
      'RequireShouldRebuildRule',
      'require_should_rebuild',
      () => RequireShouldRebuildRule(),
    );
    testRule(
      'RequireSuperDisposeCallRule',
      'require_super_dispose_call',
      () => RequireSuperDisposeCallRule(),
    );
    testRule(
      'RequireSuperInitStateCallRule',
      'require_super_init_state_call',
      () => RequireSuperInitStateCallRule(),
    );
    testRule(
      'AvoidSetStateInDisposeRule',
      'avoid_set_state_in_dispose',
      () => AvoidSetStateInDisposeRule(),
    );
    testRule(
      'RequireWidgetsBindingCallbackRule',
      'require_widgets_binding_callback',
      () => RequireWidgetsBindingCallbackRule(),
    );
    testRule(
      'AvoidGlobalKeysInStateRule',
      'avoid_global_keys_in_state',
      () => AvoidGlobalKeysInStateRule(),
    );
    testRule(
      'AvoidExpensiveDidChangeDependenciesRule',
      'avoid_expensive_did_change_dependencies',
      () => AvoidExpensiveDidChangeDependenciesRule(),
    );
  });
  group('Widget Lifecycle Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/widget_lifecycle');

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
          'example/lib/widget_lifecycle/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture checks while migrating to analyzer-backed behavior tests.

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture checks while migrating to analyzer-backed behavior tests.
}
