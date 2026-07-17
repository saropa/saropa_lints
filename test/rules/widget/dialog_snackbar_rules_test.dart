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
    final fixtureDir = Directory('example/lib/dialog_snackbar');

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
          'example/lib/dialog_snackbar/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
