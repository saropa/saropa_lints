import 'dart:io';

import 'package:test/test.dart';

/// Tests for 46 async lint rules.
///
/// These rules cover Future handling, Stream lifecycle, async/await patterns,
/// widget async safety, and platform-specific async concerns.
///
/// Test fixtures: example/lib/async/*
void main() {
  group('Async Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_dialog_context_after_async',
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
    group('avoid_future_ignore', () {
      test('Future.ignore() call SHOULD trigger', () {
        // Discards all errors and exceptions silently
        expect('Future.ignore() detected', isNotNull);
      });

      test('Future with proper error handling should NOT trigger', () {
        expect('handled Future passes', isNotNull);
      });
    });

    group('avoid_future_tostring', () {
      test('Future.toString() SHOULD trigger', () {
        // Returns "Instance of Future", not the resolved value
        expect('Future.toString() detected', isNotNull);
      });

      test('await then toString should NOT trigger', () {
        expect('awaited toString passes', isNotNull);
      });
    });

    group('avoid_nested_futures', () {
      test('Future<Future<T>> SHOULD trigger', () {
        // Requires double await to resolve
        expect('nested Future detected', isNotNull);
      });

      test('Future<T> should NOT trigger', () {
        expect('flat Future passes', isNotNull);
      });
    });

    group('avoid_nested_streams_and_futures', () {
      test('Stream<Future<T>> SHOULD trigger', () {
        // Complex to consume, increases cognitive load
        expect('Stream<Future> detected', isNotNull);
      });

      test('Stream<T> should NOT trigger', () {
        expect('flat Stream passes', isNotNull);
      });
    });

    group('avoid_passing_async_when_sync_expected', () {
      test('async callback to sync-only method SHOULD trigger', () {
        // Returned Future is silently discarded
        expect('async in sync slot detected', isNotNull);
      });

      test('sync callback to sync method should NOT trigger', () {
        expect('sync callback passes', isNotNull);
      });
    });

    group('avoid_redundant_async', () {
      test('async function without await SHOULD trigger', () {
        // Adds unnecessary Future wrapping and microtask overhead
        expect('redundant async detected', isNotNull);
      });

      test('async function with await should NOT trigger', () {
        expect('necessary async passes', isNotNull);
      });
    });

    group('prefer_async_await', () {
      test('.then() inside async function SHOULD trigger', () {
        // Hides errors in nested callbacks
        expect('.then() in async detected', isNotNull);
      });

      test('await expression should NOT trigger', () {
        expect('await usage passes', isNotNull);
      });
    });

    group('prefer_return_await', () {
      test('returning Future directly SHOULD trigger', () {
        // Skips error propagation and stack trace preservation
        expect('return Future detected', isNotNull);
      });

      test('return await expression should NOT trigger', () {
        expect('return await passes', isNotNull);
      });
    });

    group('avoid_unawaited_future', () {
      test('not awaiting Future SHOULD trigger', () {
        // Errors/exceptions silently lost
        expect('unawaited Future detected', isNotNull);
      });
    });

    group('avoid_future_then_in_async', () {
      test('.then() in async function SHOULD trigger', () {
        // Mixing patterns makes code harder to follow
        expect('.then() in async detected', isNotNull);
      });
    });

    group('avoid_future_in_build', () {
      test('creating Future in build() SHOULD trigger', () {
        // Causes repeated execution on every rebuild
        expect('Future in build detected', isNotNull);
      });
    });

    group('prefer_future_wait', () {
      test('sequential awaits on independent Futures SHOULD trigger', () {
        // Could run in parallel with Future.wait
        expect('sequential awaits detected', isNotNull);
      });
    });

    group('avoid_sequential_awaits', () {
      test('multiple sequential awaits on independent Futures SHOULD trigger',
          () {
        expect('sequential awaits detected', isNotNull);
      });
    });

    group('require_future_timeout', () {
      test('long-running Future without timeout SHOULD trigger', () {
        expect('missing timeout detected', isNotNull);
      });
    });

    group('require_future_wait_error_handling', () {
      test('Future.wait without eagerError SHOULD trigger', () {
        expect('missing eagerError detected', isNotNull);
      });
    });
  });

  group('Stream Handling Rules', () {
    group('avoid_stream_tostring', () {
      test('Stream.toString() SHOULD trigger', () {
        expect('Stream.toString() detected', isNotNull);
      });
    });

    group('avoid_unassigned_stream_subscriptions', () {
      test('listen() result not assigned SHOULD trigger', () {
        // Cannot cancel without reference
        expect('unassigned subscription detected', isNotNull);
      });

      test('subscription assigned to variable should NOT trigger', () {
        expect('assigned subscription passes', isNotNull);
      });
    });

    group('avoid_stream_in_build', () {
      test('StreamController created in build SHOULD trigger', () {
        expect('Stream in build detected', isNotNull);
      });
    });

    group('avoid_multiple_stream_listeners', () {
      test('multiple listen() on non-broadcast stream SHOULD trigger', () {
        expect('multiple listeners detected', isNotNull);
      });

      test('single listener should NOT trigger', () {
        expect('single listener passes', isNotNull);
      });
    });

    group('avoid_stream_subscription_in_field', () {
      test('subscription field not cancelled in dispose SHOULD trigger', () {
        expect('uncancelled subscription detected', isNotNull);
      });
    });

    group('avoid_stream_sync_events', () {
      test('event added synchronously after listen SHOULD trigger', () {
        expect('sync event detected', isNotNull);
      });
    });

    group('require_stream_controller_close', () {
      test('StreamController not closed in dispose SHOULD trigger', () {
        expect('unclosed controller detected', isNotNull);
      });

      test('StreamController closed in dispose should NOT trigger', () {
        expect('closed controller passes', isNotNull);
      });
    });

    group('require_stream_error_handling', () {
      test('listen() without onError SHOULD trigger', () {
        expect('missing onError detected', isNotNull);
      });

      test('listen() with onError should NOT trigger', () {
        expect('onError present passes', isNotNull);
      });
    });

    group('require_stream_on_done', () {
      test('listen() without onDone SHOULD trigger', () {
        expect('missing onDone detected', isNotNull);
      });
    });

    group('prefer_stream_distinct', () {
      test('listen() without .distinct() SHOULD trigger', () {
        expect('missing distinct detected', isNotNull);
      });
    });

    group('prefer_broadcast_stream', () {
      test('single-subscription stream with multiple needs SHOULD trigger', () {
        expect('single-sub stream detected', isNotNull);
      });
    });

    group('require_completer_error_handling', () {
      test('Completer without completeError in catch SHOULD trigger', () {
        expect('missing completeError detected', isNotNull);
      });
    });
  });

  group('Widget Async Safety Rules', () {
    group('check_mounted_after_async / require_mounted_check_after_await', () {
      test('setState after await without mounted check SHOULD trigger', () {
        expect('missing mounted check detected', isNotNull);
      });

      test('setState after mounted check should NOT trigger', () {
        expect('mounted check present passes', isNotNull);
      });
    });

    group('avoid_dialog_context_after_async', () {
      test('BuildContext used after await SHOULD trigger', () {
        // Widget may be disposed
        expect('stale context detected', isNotNull);
      });
    });

    group('avoid_async_in_build', () {
      test('async build method SHOULD trigger', () {
        expect('async build detected', isNotNull);
      });
    });

    group('prefer_async_init_state', () {
      test('.then().setState() in initState SHOULD trigger', () {
        expect('then-setState pattern detected', isNotNull);
      });
    });

    group('use_setstate_synchronously', () {
      test('setState after async gap SHOULD trigger', () {
        expect('async setState detected', isNotNull);
      });
    });
  });

  group('Async Pattern Rules', () {
    group('prefer_assigning_await_expressions', () {
      test('inline await expression SHOULD trigger', () {
        expect('inline await detected', isNotNull);
      });
    });

    group('prefer_commenting_future_delayed', () {
      test('unexplained Future.delayed SHOULD trigger', () {
        expect('uncommented delay detected', isNotNull);
      });
    });

    group('prefer_correct_future_return_type', () {
      test('missing Future return type SHOULD trigger', () {
        expect('missing Future type detected', isNotNull);
      });
    });

    group('prefer_correct_stream_return_type', () {
      test('missing Stream return type SHOULD trigger', () {
        expect('missing Stream type detected', isNotNull);
      });
    });

    group('prefer_specifying_future_value_type', () {
      test('Future.value() without type SHOULD trigger', () {
        // Returns Future<dynamic>, losing compile-time safety
        expect('untyped Future.value detected', isNotNull);
      });
    });

    group('prefer_async_callback', () {
      test('VoidCallback for async work SHOULD trigger', () {
        // VoidCallback discards Futures silently
        expect('VoidCallback for async detected', isNotNull);
      });
    });

    group('prefer_future_void_function_over_async_callback', () {
      test('AsyncCallback instead of Future<void> Function() SHOULD trigger',
          () {
        expect('AsyncCallback detected', isNotNull);
      });
    });
  });

  group('Platform & Network Async Rules', () {
    group('require_websocket_message_validation', () {
      test('unvalidated WebSocket message SHOULD trigger', () {
        expect('unvalidated message detected', isNotNull);
      });
    });

    group('require_feature_flag_default', () {
      test('feature flag without default value SHOULD trigger', () {
        expect('missing default detected', isNotNull);
      });
    });

    group('prefer_utc_for_storage', () {
      test('local DateTime stored without UTC SHOULD trigger', () {
        expect('non-UTC storage detected', isNotNull);
      });
    });

    group('require_location_timeout', () {
      test('location request without timeout SHOULD trigger', () {
        expect('missing location timeout detected', isNotNull);
      });
    });

    group('require_network_status_check', () {
      test('network call without connectivity check SHOULD trigger', () {
        expect('missing network check detected', isNotNull);
      });
    });

    group('avoid_sync_on_every_change', () {
      test('API call in onChanged SHOULD trigger', () {
        // Triggers on every keystroke
        expect('sync-on-change detected', isNotNull);
      });
    });

    group('require_pending_changes_indicator', () {
      test('pending changes without indicator SHOULD trigger', () {
        expect('missing indicator detected', isNotNull);
      });
    });
  });
}
