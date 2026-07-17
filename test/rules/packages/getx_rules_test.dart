import 'dart:io';

import 'package:saropa_lints/src/rules/packages/getx_rules.dart';
import 'package:test/test.dart';

/// Tests for 22 Getx lint rules.
///
/// Test fixtures: example_packages/lib/getx/*
void main() {
  group('Getx Rules - Rule Instantiation', () {
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
      'RequireGetxWorkerDisposeRule',
      'require_getx_worker_dispose',
      () => RequireGetxWorkerDisposeRule(),
    );
    testRule(
      'RequireGetxPermanentCleanupRule',
      'require_getx_permanent_cleanup',
      () => RequireGetxPermanentCleanupRule(),
    );
    testRule(
      'AvoidGetxContextOutsideWidgetRule',
      'avoid_getx_context_outside_widget',
      () => AvoidGetxContextOutsideWidgetRule(),
    );
    testRule(
      'AvoidGetxGlobalNavigationRule',
      'avoid_getx_global_navigation',
      () => AvoidGetxGlobalNavigationRule(),
    );
    testRule(
      'RequireGetxBindingRoutesRule',
      'require_getx_binding_routes',
      () => RequireGetxBindingRoutesRule(),
    );
    testRule(
      'AvoidGetxDialogSnackbarInControllerRule',
      'avoid_getx_dialog_snackbar_in_controller',
      () => AvoidGetxDialogSnackbarInControllerRule(),
    );
    testRule(
      'RequireGetxLazyPutRule',
      'require_getx_lazy_put',
      () => RequireGetxLazyPutRule(),
    );
    testRule(
      'AvoidGetFindInBuildRule',
      'avoid_get_find_in_build',
      () => AvoidGetFindInBuildRule(),
    );
    testRule(
      'RequireGetxControllerDisposeRule',
      'require_getx_controller_dispose',
      () => RequireGetxControllerDisposeRule(),
    );
    testRule(
      'AvoidObsOutsideControllerRule',
      'avoid_obs_outside_controller',
      () => AvoidObsOutsideControllerRule(),
    );
    testRule(
      'ProperGetxSuperCallsRule',
      'proper_getx_super_calls',
      () => ProperGetxSuperCallsRule(),
    );
    testRule(
      'AlwaysRemoveGetxListenerRule',
      'always_remove_getx_listener',
      () => AlwaysRemoveGetxListenerRule(),
    );
    testRule(
      'AvoidGetxRxInsideBuildRule',
      'avoid_getx_rx_inside_build',
      () => AvoidGetxRxInsideBuildRule(),
    );
    testRule(
      'AvoidMutableRxVariablesRule',
      'avoid_mutable_rx_variables',
      () => AvoidMutableRxVariablesRule(),
    );
    testRule(
      'DisposeGetxFieldsRule',
      'dispose_getx_fields',
      () => DisposeGetxFieldsRule(),
    );
    testRule(
      'PreferGetxBuilderRule',
      'prefer_getx_builder',
      () => PreferGetxBuilderRule(),
    );
    testRule(
      'RequireGetxBindingRule',
      'require_getx_binding',
      () => RequireGetxBindingRule(),
    );
    testRule(
      'AvoidGetxGlobalStateRule',
      'avoid_getx_global_state',
      () => AvoidGetxGlobalStateRule(),
    );
    testRule(
      'AvoidGetxStaticContextRule',
      'avoid_getx_static_context',
      () => AvoidGetxStaticContextRule(),
    );
    testRule(
      'AvoidTightCouplingWithGetxRule',
      'avoid_tight_coupling_with_getx',
      () => AvoidTightCouplingWithGetxRule(),
    );
    testRule(
      'AvoidGetxStaticGetRule',
      'avoid_getx_static_get',
      () => AvoidGetxStaticGetRule(),
    );
    testRule(
      'AvoidGetxBuildContextBypassRule',
      'avoid_getx_build_context_bypass',
      () => AvoidGetxBuildContextBypassRule(),
    );
    testRule(
      'AvoidGetxRxNestedObsRule',
      'avoid_getx_rx_nested_obs',
      () => AvoidGetxRxNestedObsRule(),
    );
  });
  group('Getx Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/getx');

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
      test('$fixture fixture exists', () {
        final file = File('example_packages/lib/getx/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
