import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/widget/dialog_snackbar_rules.dart';

/// Tests for 6 Dialog & SnackBar lint rules.
///
/// Test fixtures: example/lib/dialog_snackbar/*
void main() {
  group('Dialog Snackbar Rules - Rule Instantiation', () {
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
      'RequireSnackbarDurationRule',
      'require_snackbar_duration',
      () => RequireSnackbarDurationRule(),
    );

    testRule(
      'RequireDialogBarrierDismissibleRule',
      'require_dialog_barrier_dismissible',
      () => RequireDialogBarrierDismissibleRule(),
    );

    testRule(
      'RequireDialogResultHandlingRule',
      'require_dialog_result_handling',
      () => RequireDialogResultHandlingRule(),
    );

    testRule(
      'AvoidSnackbarQueueBuildupRule',
      'avoid_snackbar_queue_buildup',
      () => AvoidSnackbarQueueBuildupRule(),
    );

    testRule(
      'PreferAdaptiveDialogRule',
      'prefer_adaptive_dialog',
      () => PreferAdaptiveDialogRule(),
    );

    testRule(
      'RequireSnackbarActionForUndoRule',
      'require_snackbar_action_for_undo',
      () => RequireSnackbarActionForUndoRule(),
    );
  });

  group('Dialog & SnackBar Rules - Fixture Verification', () {
    final fixtures = [
      'require_snackbar_duration',
      'require_dialog_barrier_dismissible',
      'require_dialog_result_handling',
      'avoid_snackbar_queue_buildup',
      'prefer_adaptive_dialog',
      'require_snackbar_action_for_undo',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/dialog_snackbar/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
