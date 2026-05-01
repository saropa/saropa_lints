import 'dart:io';

import 'package:saropa_lints/src/rules/core/async_rules.dart';
import 'package:test/test.dart';

/// Tests for 46 async lint rules.
///
/// These rules cover Future handling, Stream lifecycle, async/await patterns,
/// widget async safety, and platform-specific async concerns.
///
/// Test fixtures: example/lib/async/*
void main() {
  group('Async Rules - Rule Instantiation', () {
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
      'AvoidFutureIgnoreRule',
      'avoid_future_ignore',
      () => AvoidFutureIgnoreRule(),
    );
    testRule(
      'AvoidFutureToStringRule',
      'avoid_future_tostring',
      () => AvoidFutureToStringRule(),
    );
    testRule(
      'AvoidNestedFuturesRule',
      'avoid_nested_futures',
      () => AvoidNestedFuturesRule(),
    );
    testRule(
      'AvoidNestedStreamsAndFuturesRule',
      'avoid_nested_streams_and_futures',
      () => AvoidNestedStreamsAndFuturesRule(),
    );
    testRule(
      'AvoidPassingAsyncWhenSyncExpectedRule',
      'avoid_passing_async_when_sync_expected',
      () => AvoidPassingAsyncWhenSyncExpectedRule(),
    );
    testRule(
      'AvoidRedundantAsyncRule',
      'avoid_redundant_async',
      () => AvoidRedundantAsyncRule(),
    );
    testRule(
      'AvoidStreamToStringRule',
      'avoid_stream_tostring',
      () => AvoidStreamToStringRule(),
    );
    testRule(
      'AvoidUnassignedStreamSubscriptionsRule',
      'avoid_unassigned_stream_subscriptions',
      () => AvoidUnassignedStreamSubscriptionsRule(),
    );
    testRule(
      'PreferAsyncAwaitRule',
      'prefer_async_await',
      () => PreferAsyncAwaitRule(),
    );
    testRule(
      'PreferAssigningAwaitExpressionsRule',
      'prefer_assigning_await_expressions',
      () => PreferAssigningAwaitExpressionsRule(),
    );
    testRule(
      'PreferCommentingFutureDelayedRule',
      'prefer_commenting_future_delayed',
      () => PreferCommentingFutureDelayedRule(),
    );
    testRule(
      'PreferCorrectFutureReturnTypeRule',
      'prefer_correct_future_return_type',
      () => PreferCorrectFutureReturnTypeRule(),
    );
    testRule(
      'PreferCorrectStreamReturnTypeRule',
      'prefer_correct_stream_return_type',
      () => PreferCorrectStreamReturnTypeRule(),
    );
    testRule(
      'PreferSpecifyingFutureValueTypeRule',
      'prefer_specifying_future_value_type',
      () => PreferSpecifyingFutureValueTypeRule(),
    );
    testRule(
      'PreferReturnAwaitRule',
      'prefer_return_await',
      () => PreferReturnAwaitRule(),
    );
    testRule(
      'PreferAsyncCallbackRule',
      'prefer_async_callback',
      () => PreferAsyncCallbackRule(),
    );
    testRule(
      'PreferFutureVoidFunctionOverAsyncCallbackRule',
      'prefer_future_void_function_over_async_callback',
      () => PreferFutureVoidFunctionOverAsyncCallbackRule(),
    );
    testRule(
      'AvoidDialogContextAfterAsyncRule',
      'avoid_dialog_context_after_async',
      () => AvoidDialogContextAfterAsyncRule(),
    );
    testRule(
      'CheckMountedAfterAsyncRule',
      'check_mounted_after_async',
      () => CheckMountedAfterAsyncRule(),
    );
    testRule(
      'RequireWebsocketMessageValidationRule',
      'require_websocket_message_validation',
      () => RequireWebsocketMessageValidationRule(),
    );
    testRule(
      'RequireFeatureFlagDefaultRule',
      'require_feature_flag_default',
      () => RequireFeatureFlagDefaultRule(),
    );
    testRule(
      'PreferUtcForStorageRule',
      'prefer_utc_for_storage',
      () => PreferUtcForStorageRule(),
    );
    testRule(
      'RequireLocationTimeoutRule',
      'require_location_timeout',
      () => RequireLocationTimeoutRule(),
    );
    testRule(
      'AvoidStreamInBuildRule',
      'avoid_stream_in_build',
      () => AvoidStreamInBuildRule(),
    );
    testRule(
      'RequireStreamControllerCloseRule',
      'require_stream_controller_close',
      () => RequireStreamControllerCloseRule(),
    );
    testRule(
      'AvoidMultipleStreamListenersRule',
      'avoid_multiple_stream_listeners',
      () => AvoidMultipleStreamListenersRule(),
    );
    testRule(
      'RequireStreamErrorHandlingRule',
      'require_stream_error_handling',
      () => RequireStreamErrorHandlingRule(),
    );
    testRule(
      'RequireFutureTimeoutRule',
      'require_future_timeout',
      () => RequireFutureTimeoutRule(),
    );
    testRule(
      'RequireFutureWaitErrorHandlingRule',
      'require_future_wait_error_handling',
      () => RequireFutureWaitErrorHandlingRule(),
    );
    testRule(
      'RequireStreamOnDoneRule',
      'require_stream_on_done',
      () => RequireStreamOnDoneRule(),
    );
    testRule(
      'RequireCompleterErrorHandlingRule',
      'require_completer_error_handling',
      () => RequireCompleterErrorHandlingRule(),
    );
    testRule(
      'AvoidStreamSubscriptionInFieldRule',
      'avoid_stream_subscription_in_field',
      () => AvoidStreamSubscriptionInFieldRule(),
    );
    testRule(
      'AvoidFutureThenInAsyncRule',
      'avoid_future_then_in_async',
      () => AvoidFutureThenInAsyncRule(),
    );
    testRule(
      'AvoidUnawaitedFutureRule',
      'avoid_unawaited_future',
      () => AvoidUnawaitedFutureRule(),
    );
    testRule(
      'PreferFutureWaitRule',
      'prefer_future_wait',
      () => PreferFutureWaitRule(),
    );
    testRule(
      'PreferStreamDistinctRule',
      'prefer_stream_distinct',
      () => PreferStreamDistinctRule(),
    );
    testRule(
      'PreferBroadcastStreamRule',
      'prefer_broadcast_stream',
      () => PreferBroadcastStreamRule(),
    );
    testRule(
      'AvoidFutureInBuildRule',
      'avoid_future_in_build',
      () => AvoidFutureInBuildRule(),
    );
    testRule(
      'RequireMountedCheckAfterAwaitRule',
      'require_mounted_check_after_await',
      () => RequireMountedCheckAfterAwaitRule(),
    );
    testRule(
      'AvoidAsyncInBuildRule',
      'avoid_async_in_build',
      () => AvoidAsyncInBuildRule(),
    );
    testRule(
      'PreferAsyncInitStateRule',
      'prefer_async_init_state',
      () => PreferAsyncInitStateRule(),
    );
    testRule(
      'RequireNetworkStatusCheckRule',
      'require_network_status_check',
      () => RequireNetworkStatusCheckRule(),
    );
    testRule(
      'AvoidSyncOnEveryChangeRule',
      'avoid_sync_on_every_change',
      () => AvoidSyncOnEveryChangeRule(),
    );
    testRule(
      'RequirePendingChangesIndicatorRule',
      'require_pending_changes_indicator',
      () => RequirePendingChangesIndicatorRule(),
    );
    testRule(
      'AvoidStreamSyncEventsRule',
      'avoid_stream_sync_events',
      () => AvoidStreamSyncEventsRule(),
    );
    testRule(
      'AvoidSequentialAwaitsRule',
      'avoid_sequential_awaits',
      () => AvoidSequentialAwaitsRule(),
    );
    testRule(
      'AvoidVoidAsyncRule',
      'avoid_void_async',
      () => AvoidVoidAsyncRule(),
    );
    testRule(
      'AvoidRedundantAwaitRule',
      'avoid_redundant_await',
      () => AvoidRedundantAwaitRule(),
    );
  });
  group('Async Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_dialog_context_after_async',
      'avoid_redundant_await',
      'avoid_void_async',
      'avoid_future_ignore',
      'avoid_future_tostring',
      'avoid_multiple_stream_listeners',
      'avoid_nested_futures',
      'avoid_nested_streams_and_futures',
      'avoid_passing_async_when_sync_expected',
      'avoid_redundant_async',
      'avoid_sequential_awaits',
      'avoid_stream_in_build',
      'avoid_stream_subscription_in_field',
      'avoid_stream_sync_events',
      'avoid_stream_tostring',
      'avoid_sync_on_every_change',
      'avoid_unassigned_stream_subscriptions',
      'prefer_assigning_await_expressions',
      'prefer_async_await',
      'prefer_async_callback',
      'prefer_async_init_state',
      'prefer_cancellation_token_pattern',
      'prefer_commenting_future_delayed',
      'prefer_correct_future_return_type',
      'prefer_correct_stream_return_type',
      'prefer_future_void_function_over_async_callback',
      'prefer_return_await',
      'prefer_specifying_future_value_type',
      'prefer_utc_for_storage',
      'require_completer_error_handling',
      'require_feature_flag_default',
      'require_future_timeout',
      'require_future_wait_error_handling',
      'require_location_timeout',
      'require_network_status_check',
      'require_pending_changes_indicator',
      'require_stream_controller_close',
      'require_stream_error_handling',
      'require_stream_on_done',
      'require_websocket_message_validation',
      'use_setstate_synchronously',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/async/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Future Handling Rules', () {
    test('avoid_future_ignore offers quick fix (replace with unawaited)', () {
      final rule = AvoidFutureIgnoreRule();
      expect(rule.fixGenerators, isNotEmpty);
    });
  });

  group('AvoidRedundantAwaitRule', () {
    test(
      'diagnostic text is v3 (AnimationController TickerFuture methods)',
      () {
        final rule = AvoidRedundantAwaitRule();
        expect(rule.code.problemMessage, contains('{v3}'));
      },
    );

    test('fixture keeps BAD expect_lint and Future-implementer regression', () {
      final source = File(
        'example/lib/async/avoid_redundant_await_fixture.dart',
      ).readAsStringSync();
      expect(source, contains('// expect_lint: avoid_redundant_await'));
      expect(source, contains('_DelegatingFuture'));
      expect(source, contains('goodImplementsFuture'));
      expect(source, contains('goodAnimationControllerAwaits'));
      expect(source, contains('await controller.forward();'));
      expect(source, contains('await controller.reverse();'));
      expect(source, contains('await controller.animateTo('));
      expect(source, contains('await controller.animateBack('));
      expect(source, contains('await controller.animateWith('));
      expect(source, contains('await controller.repeat();'));
      expect(source, contains('await controller.fling();'));
      expect(source, contains('await someInt'));
    });
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata,
  // fixture verification, and targeted metadata checks while migrating to
  // analyzer-backed behavior tests.
}
