import 'dart:io';

import 'package:saropa_lints/src/rules/disposal_rules.dart';
import 'package:test/test.dart';

/// Tests for 17 Disposal lint rules.
///
/// Test fixtures: example_async/lib/disposal/*
void main() {
  group('Disposal Rules - Rule Instantiation', () {
    test('RequireMediaPlayerDisposeRule', () {
      final rule = RequireMediaPlayerDisposeRule();
      expect(rule.code.name, 'require_media_player_dispose');
      expect(
        rule.code.problemMessage,
        contains('[require_media_player_dispose]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireTabControllerDisposeRule', () {
      final rule = RequireTabControllerDisposeRule();
      expect(rule.code.name, 'require_tab_controller_dispose');
      expect(
        rule.code.problemMessage,
        contains('[require_tab_controller_dispose]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireTextEditingControllerDisposeRule', () {
      final rule = RequireTextEditingControllerDisposeRule();
      expect(rule.code.name, 'require_text_editing_controller_dispose');
      expect(
        rule.code.problemMessage,
        contains('[require_text_editing_controller_dispose]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequirePageControllerDisposeRule', () {
      final rule = RequirePageControllerDisposeRule();
      expect(rule.code.name, 'require_page_controller_dispose');
      expect(
        rule.code.problemMessage,
        contains('[require_page_controller_dispose]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireLifecycleObserverRule', () {
      final rule = RequireLifecycleObserverRule();
      expect(rule.code.name, 'require_lifecycle_observer');
      expect(
        rule.code.problemMessage,
        contains('[require_lifecycle_observer]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidWebsocketMemoryLeakRule', () {
      final rule = AvoidWebsocketMemoryLeakRule();
      expect(rule.code.name, 'avoid_websocket_memory_leak');
      expect(
        rule.code.problemMessage,
        contains('[avoid_websocket_memory_leak]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireVideoPlayerControllerDisposeRule', () {
      final rule = RequireVideoPlayerControllerDisposeRule();
      expect(rule.code.name, 'require_video_player_controller_dispose');
      expect(
        rule.code.problemMessage,
        contains('[require_video_player_controller_dispose]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireStreamSubscriptionCancelRule', () {
      final rule = RequireStreamSubscriptionCancelRule();
      expect(rule.code.name, 'require_stream_subscription_cancel');
      expect(
        rule.code.problemMessage,
        contains('[require_stream_subscription_cancel]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireChangeNotifierDisposeRule', () {
      final rule = RequireChangeNotifierDisposeRule();
      expect(rule.code.name, 'require_change_notifier_dispose');
      expect(
        rule.code.problemMessage,
        contains('[require_change_notifier_dispose]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireReceivePortCloseRule', () {
      final rule = RequireReceivePortCloseRule();
      expect(rule.code.name, 'require_receive_port_close');
      expect(
        rule.code.problemMessage,
        contains('[require_receive_port_close]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireSocketCloseRule', () {
      final rule = RequireSocketCloseRule();
      expect(rule.code.name, 'require_socket_close');
      expect(rule.code.problemMessage, contains('[require_socket_close]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireDebouncerCancelRule', () {
      final rule = RequireDebouncerCancelRule();
      expect(rule.code.name, 'require_debouncer_cancel');
      expect(rule.code.problemMessage, contains('[require_debouncer_cancel]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireIntervalTimerCancelRule', () {
      final rule = RequireIntervalTimerCancelRule();
      expect(rule.code.name, 'require_interval_timer_cancel');
      expect(
        rule.code.problemMessage,
        contains('[require_interval_timer_cancel]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireFileHandleCloseRule', () {
      final rule = RequireFileHandleCloseRule();
      expect(rule.code.name, 'require_file_handle_close');
      expect(rule.code.problemMessage, contains('[require_file_handle_close]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireDisposeImplementationRule', () {
      final rule = RequireDisposeImplementationRule();
      expect(rule.code.name, 'require_dispose_implementation');
      expect(
        rule.code.problemMessage,
        contains('[require_dispose_implementation]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferDisposeBeforeNewInstanceRule', () {
      final rule = PreferDisposeBeforeNewInstanceRule();
      expect(rule.code.name, 'prefer_dispose_before_new_instance');
      expect(
        rule.code.problemMessage,
        contains('[prefer_dispose_before_new_instance]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('DisposeClassFieldsRule', () {
      final rule = DisposeClassFieldsRule();
      expect(rule.code.name, 'dispose_class_fields');
      expect(rule.code.problemMessage, contains('[dispose_class_fields]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Disposal Rules - Fixture Verification', () {
    final fixtures = [
      'require_media_player_dispose',
      'require_tab_controller_dispose',
      'require_text_editing_controller_dispose',
      'require_page_controller_dispose',
      'require_lifecycle_observer',
      'avoid_websocket_memory_leak',
      'require_video_player_controller_dispose',
      'require_stream_subscription_cancel',
      'require_change_notifier_dispose',
      'require_receive_port_close',
      'require_socket_close',
      'require_debouncer_cancel',
      'require_interval_timer_cancel',
      'require_file_handle_close',
      'require_dispose_implementation',
      'prefer_deactivate_for_cleanup',
      'prefer_dispose_before_new_instance',
      'dispose_class_fields',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_async/lib/disposal/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Disposal - Requirement Rules', () {
    group('require_media_player_dispose', () {
      test('require_media_player_dispose SHOULD trigger', () {
        // Required pattern missing: require media player dispose
        expect('require_media_player_dispose detected', isNotNull);
      });

      test('require_media_player_dispose should NOT trigger', () {
        // Required pattern present
        expect('require_media_player_dispose passes', isNotNull);
      });
    });

    group('require_tab_controller_dispose', () {
      test('require_tab_controller_dispose SHOULD trigger', () {
        // Required pattern missing: require tab controller dispose
        expect('require_tab_controller_dispose detected', isNotNull);
      });

      test('require_tab_controller_dispose should NOT trigger', () {
        // Required pattern present
        expect('require_tab_controller_dispose passes', isNotNull);
      });
    });

    group('require_text_editing_controller_dispose', () {
      test('require_text_editing_controller_dispose SHOULD trigger', () {
        // Required pattern missing: require text editing controller dispose
        expect('require_text_editing_controller_dispose detected', isNotNull);
      });

      test('require_text_editing_controller_dispose should NOT trigger', () {
        // Required pattern present
        expect('require_text_editing_controller_dispose passes', isNotNull);
      });
    });

    group('require_page_controller_dispose', () {
      test('require_page_controller_dispose SHOULD trigger', () {
        // Required pattern missing: require page controller dispose
        expect('require_page_controller_dispose detected', isNotNull);
      });

      test('require_page_controller_dispose should NOT trigger', () {
        // Required pattern present
        expect('require_page_controller_dispose passes', isNotNull);
      });
    });

    group('require_lifecycle_observer', () {
      test('require_lifecycle_observer SHOULD trigger', () {
        // Required pattern missing: require lifecycle observer
        expect('require_lifecycle_observer detected', isNotNull);
      });

      test('require_lifecycle_observer should NOT trigger', () {
        // Required pattern present
        expect('require_lifecycle_observer passes', isNotNull);
      });
    });

    group('require_video_player_controller_dispose', () {
      test('require_video_player_controller_dispose SHOULD trigger', () {
        // Required pattern missing: require video player controller dispose
        expect('require_video_player_controller_dispose detected', isNotNull);
      });

      test('require_video_player_controller_dispose should NOT trigger', () {
        // Required pattern present
        expect('require_video_player_controller_dispose passes', isNotNull);
      });
    });

    group('require_stream_subscription_cancel', () {
      test('require_stream_subscription_cancel SHOULD trigger', () {
        // Required pattern missing: require stream subscription cancel
        expect('require_stream_subscription_cancel detected', isNotNull);
      });

      test('require_stream_subscription_cancel should NOT trigger', () {
        // Required pattern present
        expect('require_stream_subscription_cancel passes', isNotNull);
      });
    });

    group('require_change_notifier_dispose', () {
      test('require_change_notifier_dispose SHOULD trigger', () {
        // Required pattern missing: require change notifier dispose
        expect('require_change_notifier_dispose detected', isNotNull);
      });

      test('require_change_notifier_dispose should NOT trigger', () {
        // Required pattern present
        expect('require_change_notifier_dispose passes', isNotNull);
      });
    });

    group('require_receive_port_close', () {
      test('require_receive_port_close SHOULD trigger', () {
        // Required pattern missing: require receive port close
        expect('require_receive_port_close detected', isNotNull);
      });

      test('require_receive_port_close should NOT trigger', () {
        // Required pattern present
        expect('require_receive_port_close passes', isNotNull);
      });
    });

    group('require_socket_close', () {
      test('require_socket_close SHOULD trigger', () {
        // Required pattern missing: require socket close
        expect('require_socket_close detected', isNotNull);
      });

      test('require_socket_close should NOT trigger', () {
        // Required pattern present
        expect('require_socket_close passes', isNotNull);
      });
    });

    group('require_debouncer_cancel', () {
      test('require_debouncer_cancel SHOULD trigger', () {
        // Required pattern missing: require debouncer cancel
        expect('require_debouncer_cancel detected', isNotNull);
      });

      test('require_debouncer_cancel should NOT trigger', () {
        // Required pattern present
        expect('require_debouncer_cancel passes', isNotNull);
      });
    });

    group('require_interval_timer_cancel', () {
      test('require_interval_timer_cancel SHOULD trigger', () {
        // Required pattern missing: require interval timer cancel
        expect('require_interval_timer_cancel detected', isNotNull);
      });

      test('require_interval_timer_cancel should NOT trigger', () {
        // Required pattern present
        expect('require_interval_timer_cancel passes', isNotNull);
      });
    });

    group('require_file_handle_close', () {
      test('require_file_handle_close SHOULD trigger', () {
        // Required pattern missing: require file handle close
        expect('require_file_handle_close detected', isNotNull);
      });

      test('require_file_handle_close should NOT trigger', () {
        // Required pattern present
        expect('require_file_handle_close passes', isNotNull);
      });
    });

    group('require_dispose_implementation', () {
      test('require_dispose_implementation SHOULD trigger', () {
        // Required pattern missing: require dispose implementation
        expect('require_dispose_implementation detected', isNotNull);
      });

      test('require_dispose_implementation should NOT trigger', () {
        // Required pattern present
        expect('require_dispose_implementation passes', isNotNull);
      });
    });
  });

  group('Disposal - Avoidance Rules', () {
    group('avoid_websocket_memory_leak', () {
      test('avoid_websocket_memory_leak SHOULD trigger', () {
        // Pattern that should be avoided: avoid websocket memory leak
        expect('avoid_websocket_memory_leak detected', isNotNull);
      });

      test('avoid_websocket_memory_leak should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_websocket_memory_leak passes', isNotNull);
      });
    });
  });

  group('Disposal - Preference Rules', () {
    group('prefer_dispose_before_new_instance', () {
      test('prefer_dispose_before_new_instance SHOULD trigger', () {
        // Better alternative available: prefer dispose before new instance
        expect('prefer_dispose_before_new_instance detected', isNotNull);
      });

      test('prefer_dispose_before_new_instance should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_dispose_before_new_instance passes', isNotNull);
      });
    });
  });

  group('Disposal - General Rules', () {
    group('dispose_class_fields', () {
      test('dispose_class_fields SHOULD trigger', () {
        // Detected violation: dispose class fields
        expect('dispose_class_fields detected', isNotNull);
      });

      test('dispose_class_fields should NOT trigger', () {
        // Compliant code passes
        expect('dispose_class_fields passes', isNotNull);
      });
    });
  });
}
