import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/testing/testing_best_practices_rules.dart';

/// Tests for 35 Testing Best Practices lint rules.
///
/// Test fixtures: example/lib/testing_best_practices/*
// testWidgets, mocks, and async test hygiene; see fixtures for each rule.
void main() {
  group('Testing Best Practices Rules - Rule Instantiation', () {
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
      'RequireTestAssertionsRule',
      'require_test_assertions',
      () => RequireTestAssertionsRule(),
    );

    testRule(
      'AvoidVagueTestDescriptionsRule',
      'avoid_vague_test_descriptions',
      () => AvoidVagueTestDescriptionsRule(),
    );

    testRule(
      'AvoidRealNetworkCallsInTestsRule',
      'avoid_real_network_calls_in_tests',
      () => AvoidRealNetworkCallsInTestsRule(),
    );

    testRule(
      'AvoidHardcodedTestDelaysRule',
      'avoid_hardcoded_test_delays',
      () => AvoidHardcodedTestDelaysRule(),
    );

    testRule(
      'RequireTestSetupTeardownRule',
      'require_test_setup_teardown',
      () => RequireTestSetupTeardownRule(),
    );

    testRule(
      'RequirePumpAfterInteractionRule',
      'require_pump_after_interaction',
      () => RequirePumpAfterInteractionRule(),
    );

    testRule(
      'AvoidProductionConfigInTestsRule',
      'avoid_production_config_in_tests',
      () => AvoidProductionConfigInTestsRule(),
    );

    testRule(
      'PreferPumpAndSettleRule',
      'prefer_pump_and_settle',
      () => PreferPumpAndSettleRule(),
    );

    testRule(
      'AvoidTestSleepRule',
      'avoid_test_sleep',
      () => AvoidTestSleepRule(),
    );

    testRule(
      'AvoidFindByTextRule',
      'avoid_find_by_text',
      () => AvoidFindByTextRule(),
    );

    testRule(
      'RequireTestKeysRule',
      'require_test_keys',
      () => RequireTestKeysRule(),
    );

    testRule(
      'RequireArrangeActAssertRule',
      'require_arrange_act_assert',
      () => RequireArrangeActAssertRule(),
    );

    testRule(
      'PreferMockNavigatorRule',
      'prefer_mock_navigator',
      () => PreferMockNavigatorRule(),
    );

    testRule(
      'AvoidRealTimerInWidgetTestRule',
      'avoid_real_timer_in_widget_test',
      () => AvoidRealTimerInWidgetTestRule(),
    );

    testRule(
      'RequireMockVerificationRule',
      'require_mock_verification',
      () => RequireMockVerificationRule(),
    );

    testRule(
      'PreferMatcherOverEqualsRule',
      'prefer_matcher_over_equals',
      () => PreferMatcherOverEqualsRule(),
    );

    testRule(
      'PreferTestWrapperRule',
      'prefer_test_wrapper',
      () => PreferTestWrapperRule(),
    );

    testRule(
      'RequireScreenSizeTestsRule',
      'require_screen_size_tests',
      () => RequireScreenSizeTestsRule(),
    );

    testRule(
      'AvoidStatefulTestSetupRule',
      'avoid_stateful_test_setup',
      () => AvoidStatefulTestSetupRule(),
    );

    testRule(
      'PreferMockHttpRule',
      'prefer_mock_http',
      () => PreferMockHttpRule(),
    );

    testRule(
      'RequireGoldenTestRule',
      'require_golden_test',
      () => RequireGoldenTestRule(),
    );

    testRule(
      'AvoidFlakyTestsRule',
      'avoid_flaky_tests',
      () => AvoidFlakyTestsRule(),
    );

    testRule(
      'PreferSingleAssertionRule',
      'prefer_single_assertion',
      () => PreferSingleAssertionRule(),
    );

    testRule('AvoidFindAllRule', 'avoid_find_all', () => AvoidFindAllRule());

    testRule(
      'RequireIntegrationTestSetupRule',
      'require_integration_test_setup',
      () => RequireIntegrationTestSetupRule(),
    );

    testRule(
      'AvoidHardcodedDelaysRule',
      'avoid_hardcoded_delays',
      () => AvoidHardcodedDelaysRule(),
    );

    testRule(
      'RequireErrorCaseTestsRule',
      'require_error_case_tests',
      () => RequireErrorCaseTestsRule(),
    );

    testRule(
      'PreferTestFindByKeyRule',
      'prefer_test_find_by_key',
      () => PreferTestFindByKeyRule(),
    );

    testRule(
      'PreferSetupTeardownRule',
      'prefer_setup_teardown',
      () => PreferSetupTeardownRule(),
    );

    testRule(
      'RequireTestDescriptionConventionRule',
      'require_test_description_convention',
      () => RequireTestDescriptionConventionRule(),
    );

    testRule(
      'PreferBlocTestPackageRule',
      'prefer_bloc_test_package',
      () => PreferBlocTestPackageRule(),
    );

    testRule(
      'PreferMockVerifyRule',
      'prefer_mock_verify',
      () => PreferMockVerifyRule(),
    );

    testRule(
      'RequireDialogTestsRule',
      'require_dialog_tests',
      () => RequireDialogTestsRule(),
    );

    testRule(
      'PreferFakePlatformRule',
      'prefer_fake_platform',
      () => PreferFakePlatformRule(),
    );

    testRule(
      'RequireTestDocumentationRule',
      'require_test_documentation',
      () => RequireTestDocumentationRule(),
    );
  });

  group('Testing Best Practices Rules - Fixture Verification', () {
    final fixtures = [
      'require_test_assertions',
      'avoid_vague_test_descriptions',
      'avoid_real_network_calls_in_tests',
      'avoid_hardcoded_test_delays',
      'require_test_setup_teardown',
      'require_pump_after_interaction',
      'avoid_production_config_in_tests',
      'prefer_pump_and_settle',
      'avoid_test_sleep',
      'avoid_find_by_text',
      'require_test_keys',
      'require_arrange_act_assert',
      'prefer_mock_navigator',
      'avoid_real_timer_in_widget_test',
      'require_mock_verification',
      'prefer_matcher_over_equals',
      'prefer_test_wrapper',
      'require_screen_size_tests',
      'avoid_stateful_test_setup',
      'prefer_mock_http',
      'require_golden_test',
      'avoid_flaky_tests',
      'prefer_single_assertion',
      'avoid_find_all',
      'require_integration_test_setup',
      'avoid_hardcoded_delays',
      'require_error_case_tests',
      'prefer_test_find_by_key',
      'prefer_setup_teardown',
      'require_test_description_convention',
      'prefer_bloc_test_package',
      'prefer_mock_verify',
      'require_dialog_tests',
      'prefer_fake_platform',
      'require_test_documentation',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/testing_best_practices/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
