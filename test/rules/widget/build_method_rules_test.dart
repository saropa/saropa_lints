import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/widget/build_method_rules.dart';

/// Tests for 11 Build Method lint rules.
///
/// Test fixtures: example/lib/build_method/*
void main() {
  group('Build Method Rules - Rule Instantiation', () {
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
      'AvoidGradientInBuildRule',
      'avoid_gradient_in_build',
      () => AvoidGradientInBuildRule(),
    );

    testRule(
      'AvoidDialogInBuildRule',
      'avoid_dialog_in_build',
      () => AvoidDialogInBuildRule(),
    );

    testRule(
      'AvoidSnackbarInBuildRule',
      'avoid_snackbar_in_build',
      () => AvoidSnackbarInBuildRule(),
    );

    testRule(
      'AvoidAnalyticsInBuildRule',
      'avoid_analytics_in_build',
      () => AvoidAnalyticsInBuildRule(),
    );

    testRule(
      'AvoidJsonEncodeInBuildRule',
      'avoid_json_encode_in_build',
      () => AvoidJsonEncodeInBuildRule(),
    );

    testRule(
      'AvoidCanvasInBuildRule',
      'avoid_canvas_operations_in_build',
      () => AvoidCanvasInBuildRule(),
    );

    testRule(
      'AvoidHardcodedFeatureFlagsRule',
      'avoid_hardcoded_feature_flags',
      () => AvoidHardcodedFeatureFlagsRule(),
    );

    testRule(
      'PreferSingleSetStateRule',
      'prefer_single_setstate',
      () => PreferSingleSetStateRule(),
    );

    testRule(
      'PreferComputeOverIsolateRunRule',
      'prefer_compute_over_isolate_run',
      () => PreferComputeOverIsolateRunRule(),
    );

    testRule(
      'PreferForLoopInChildrenRule',
      'prefer_for_loop_in_children',
      () => PreferForLoopInChildrenRule(),
    );

    testRule(
      'PreferContainerRule',
      'prefer_single_container',
      () => PreferContainerRule(),
    );
  });

  group('Build Method Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/build_method');

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
        final file = File('example/lib/build_method/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests removed; keep rule metadata and fixture checks.
}
