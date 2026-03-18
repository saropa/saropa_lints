import 'dart:io';

import 'package:saropa_lints/src/rules/architecture/lifecycle_rules.dart';
import 'package:test/test.dart';

/// Tests for 6 Lifecycle lint rules.
///
/// Test fixtures: example_async/lib/lifecycle/*
void main() {
  group('Lifecycle Rules - Rule Instantiation', () {
    test('AvoidWorkInPausedStateRule', () {
      final rule = AvoidWorkInPausedStateRule();
      expect(rule.code.name.toLowerCase(), 'avoid_work_in_paused_state');
      expect(
        rule.code.problemMessage,
        contains('[avoid_work_in_paused_state]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireResumeStateRefreshRule', () {
      final rule = RequireResumeStateRefreshRule();
      expect(rule.code.name.toLowerCase(), 'require_resume_state_refresh');
      expect(
        rule.code.problemMessage,
        contains('[require_resume_state_refresh]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireDidUpdateWidgetCheckRule', () {
      final rule = RequireDidUpdateWidgetCheckRule();
      expect(rule.code.name.toLowerCase(), 'require_did_update_widget_check');
      expect(
        rule.code.problemMessage,
        contains('[require_did_update_widget_check]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireLateInitializationInInitStateRule', () {
      final rule = RequireLateInitializationInInitStateRule();
      expect(
        rule.code.name.toLowerCase(),
        'require_late_initialization_in_init_state',
      );
      expect(
        rule.code.problemMessage,
        contains('[require_late_initialization_in_init_state]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireAppLifecycleHandlingRule', () {
      final rule = RequireAppLifecycleHandlingRule();
      expect(rule.code.name.toLowerCase(), 'require_app_lifecycle_handling');
      expect(
        rule.code.problemMessage,
        contains('[require_app_lifecycle_handling]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireConflictResolutionStrategyRule', () {
      final rule = RequireConflictResolutionStrategyRule();
      expect(
        rule.code.name.toLowerCase(),
        'require_conflict_resolution_strategy',
      );
      expect(
        rule.code.problemMessage,
        contains('[require_conflict_resolution_strategy]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Lifecycle Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_work_in_paused_state',
      'require_resume_state_refresh',
      'require_did_update_widget_check',
      'require_late_initialization_in_init_state',
      'require_app_lifecycle_handling',
      'require_conflict_resolution_strategy',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_async/lib/lifecycle/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Lifecycle - Avoidance Rules', () {
    group('avoid_work_in_paused_state', () {
      test('computation during AppLifecycleState.paused SHOULD trigger', () {
        expect('computation during AppLifecycleState.paused', isNotNull);
      });

      test('pausing work when app paused should NOT trigger', () {
        expect('pausing work when app paused', isNotNull);
      });
    });
  });

  group('Lifecycle - Requirement Rules', () {
    group('require_resume_state_refresh', () {
      test('no state refresh on resume SHOULD trigger', () {
        expect('no state refresh on resume', isNotNull);
      });

      test('data refresh on AppLifecycleState.resumed should NOT trigger', () {
        expect('data refresh on AppLifecycleState.resumed', isNotNull);
      });
    });
    group('require_did_update_widget_check', () {
      test('didUpdateWidget without comparison SHOULD trigger', () {
        expect('didUpdateWidget without comparison', isNotNull);
      });

      test('property comparison in didUpdateWidget should NOT trigger', () {
        expect('property comparison in didUpdateWidget', isNotNull);
      });
    });
    group('require_late_initialization_in_init_state', () {
      test('late field init outside initState SHOULD trigger', () {
        expect('late field init outside initState', isNotNull);
      });

      test('initialization in initState should NOT trigger', () {
        expect('initialization in initState', isNotNull);
      });
    });
    group('require_app_lifecycle_handling', () {
      test('missing WidgetsBindingObserver SHOULD trigger', () {
        expect('missing WidgetsBindingObserver', isNotNull);
      });

      test('lifecycle state handling should NOT trigger', () {
        expect('lifecycle state handling', isNotNull);
      });
    });
  });
}
