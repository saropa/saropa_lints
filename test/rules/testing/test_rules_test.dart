import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/testing/test_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 30 Test Rules lint rules.
///
/// Test fixtures: example/lib/test/*
// test/ / group / setUpAll patterns; matcher and async test style in examples.
void main() {
  group('Test Rules - Rule Instantiation', () {
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
      'AvoidDuplicateTestAssertionsRule',
      'avoid_duplicate_test_assertions',
      () => AvoidDuplicateTestAssertionsRule(),
    );

    testRule(
      'AvoidEmptyTestGroupsRule',
      'avoid_empty_test_groups',
      () => AvoidEmptyTestGroupsRule(),
    );

    testRule(
      'AvoidTopLevelMembersInTestsRule',
      'avoid_top_level_members_in_tests',
      () => AvoidTopLevelMembersInTestsRule(),
    );

    testRule(
      'PreferDescriptiveTestNameRule',
      'prefer_descriptive_test_name',
      () => PreferDescriptiveTestNameRule(),
    );

    testRule(
      'FormatTestNameRule',
      'format_test_name',
      () => FormatTestNameRule(),
    );

    testRule(
      'PreferCorrectTestFileNameRule',
      'prefer_correct_test_file_name',
      () => PreferCorrectTestFileNameRule(),
    );

    testRule(
      'AvoidTestOnRealDeviceRule',
      'avoid_test_on_real_device',
      () => AvoidTestOnRealDeviceRule(),
    );

    testRule(
      'PreferExpectLaterRule',
      'prefer_expect_later',
      () => PreferExpectLaterRule(),
    );

    testRule(
      'PreferTestStructureRule',
      'prefer_test_structure',
      () => PreferTestStructureRule(),
    );

    testRule(
      'PreferUniqueTestNamesRule',
      'prefer_unique_test_names',
      () => PreferUniqueTestNamesRule(),
    );

    testRule(
      'RequireTestGroupsRule',
      'require_test_groups',
      () => RequireTestGroupsRule(),
    );

    testRule(
      'AvoidTestCouplingRule',
      'avoid_test_coupling',
      () => AvoidTestCouplingRule(),
    );

    testRule(
      'RequireTestIsolationRule',
      'require_test_isolation',
      () => RequireTestIsolationRule(),
    );

    testRule(
      'AvoidRealDependenciesInTestsRule',
      'avoid_real_dependencies_in_tests',
      () => AvoidRealDependenciesInTestsRule(),
    );

    testRule(
      'RequireScrollTestsRule',
      'require_scroll_tests',
      () => RequireScrollTestsRule(),
    );

    testRule(
      'RequireTextInputTestsRule',
      'require_text_input_tests',
      () => RequireTextInputTestsRule(),
    );

    testRule(
      'PreferFakeOverMockRule',
      'prefer_fake_over_mock',
      () => PreferFakeOverMockRule(),
    );

    testRule(
      'RequireEdgeCaseTestsRule',
      'require_edge_case_tests',
      () => RequireEdgeCaseTestsRule(),
    );

    testRule(
      'PreferTestDataBuilderRule',
      'prefer_test_data_builder',
      () => PreferTestDataBuilderRule(),
    );

    testRule(
      'AvoidTestImplementationDetailsRule',
      'avoid_test_implementation_details',
      () => AvoidTestImplementationDetailsRule(),
    );

    testRule(
      'MissingTestAssertionRule',
      'missing_test_assertion',
      () => MissingTestAssertionRule(),
    );

    testRule(
      'AvoidAsyncCallbackInFakeAsyncRule',
      'avoid_async_callback_in_fake_async',
      () => AvoidAsyncCallbackInFakeAsyncRule(),
    );

    testRule(
      'PreferSymbolOverKeyRule',
      'prefer_symbol_over_key',
      () => PreferSymbolOverKeyRule(),
    );

    testRule(
      'RequireTestCleanupRule',
      'require_test_cleanup',
      () => RequireTestCleanupRule(),
    );

    testRule(
      'PreferTestVariantRule',
      'prefer_test_variant',
      () => PreferTestVariantRule(),
    );

    testRule(
      'RequireAccessibilityTestsRule',
      'require_accessibility_tests',
      () => RequireAccessibilityTestsRule(),
    );

    testRule(
      'RequireAnimationTestsRule',
      'require_animation_tests',
      () => RequireAnimationTestsRule(),
    );

    testRule(
      'AvoidTestPrintStatementsRule',
      'avoid_test_print_statements',
      () => AvoidTestPrintStatementsRule(),
    );

    testRule(
      'RequireMockHttpClientRule',
      'require_mock_http_client',
      () => RequireMockHttpClientRule(),
    );

    testRule(
      'RequireTestWidgetPumpRule',
      'require_test_widget_pump',
      () => RequireTestWidgetPumpRule(),
    );

    testRule(
      'RequireIntegrationTestTimeoutRule',
      'require_integration_test_timeout',
      () => RequireIntegrationTestTimeoutRule(),
    );

    testRule(
      'AvoidMisusedTestMatchersRule',
      'avoid_misused_test_matchers',
      () => AvoidMisusedTestMatchersRule(),
    );
  });

  group('Test Rules Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/test');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/test/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
