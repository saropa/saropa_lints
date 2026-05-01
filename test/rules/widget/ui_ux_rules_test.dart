import 'dart:io';

import 'package:saropa_lints/src/rules/widget/ui_ux_rules.dart';
import 'package:test/test.dart';

/// Tests for 20 Ui Ux lint rules.
///
/// Test fixtures: example/lib/ui_ux/*
void main() {
  group('Ui Ux Rules - Rule Instantiation', () {
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
      'RequireResponsiveBreakpointsRule',
      'require_responsive_breakpoints',
      () => RequireResponsiveBreakpointsRule(),
    );
    testRule(
      'PreferCachedPaintObjectsRule',
      'prefer_cached_paint_objects',
      () => PreferCachedPaintObjectsRule(),
    );
    testRule(
      'RequireCustomPainterShouldRepaintRule',
      'require_custom_painter_shouldrepaint',
      () => RequireCustomPainterShouldRepaintRule(),
    );
    testRule(
      'RequireCurrencyFormattingLocaleRule',
      'require_currency_formatting_locale',
      () => RequireCurrencyFormattingLocaleRule(),
    );
    testRule(
      'RequireNumberFormattingLocaleRule',
      'require_number_formatting_locale',
      () => RequireNumberFormattingLocaleRule(),
    );
    testRule(
      'RequireGraphqlOperationNamesRule',
      'require_graphql_operation_names',
      () => RequireGraphqlOperationNamesRule(),
    );
    testRule(
      'AvoidBadgeWithoutMeaningRule',
      'avoid_badge_without_meaning',
      () => AvoidBadgeWithoutMeaningRule(),
    );
    testRule(
      'PreferLoggerOverPrintRule',
      'prefer_logger_over_print',
      () => PreferLoggerOverPrintRule(),
    );
    testRule(
      'PreferItemExtentWhenKnownRule',
      'prefer_itemextent_when_known',
      () => PreferItemExtentWhenKnownRule(),
    );
    testRule(
      'RequireTabStatePreservationRule',
      'require_tab_state_preservation',
      () => RequireTabStatePreservationRule(),
    );
    testRule(
      'PreferSkeletonOverSpinnerRule',
      'prefer_skeleton_over_spinner',
      () => PreferSkeletonOverSpinnerRule(),
    );
    testRule(
      'RequireEmptyResultsStateRule',
      'require_empty_results_state',
      () => RequireEmptyResultsStateRule(),
    );
    testRule(
      'RequireSearchLoadingIndicatorRule',
      'require_search_loading_indicator',
      () => RequireSearchLoadingIndicatorRule(),
    );
    testRule(
      'RequireSearchDebounceRule',
      'require_search_debounce',
      () => RequireSearchDebounceRule(),
    );
    testRule(
      'RequirePaginationLoadingStateRule',
      'require_pagination_loading_state',
      () => RequirePaginationLoadingStateRule(),
    );
    testRule(
      'RequirePaginationErrorRecoveryRule',
      'require_pagination_error_recovery',
      () => RequirePaginationErrorRecoveryRule(),
    );
    testRule(
      'RequireWebViewProgressIndicatorRule',
      'require_webview_progress_indicator',
      () => RequireWebViewProgressIndicatorRule(),
    );
    testRule(
      'AvoidLoadingFlashRule',
      'avoid_loading_flash',
      () => AvoidLoadingFlashRule(),
    );
    testRule(
      'PreferAvatarLoadingPlaceholderRule',
      'prefer_avatar_loading_placeholder',
      () => PreferAvatarLoadingPlaceholderRule(),
    );
    testRule(
      'PreferAdaptiveIconsRule',
      'prefer_adaptive_icons',
      () => PreferAdaptiveIconsRule(),
    );
    testRule(
      'PreferMasterDetailForLargeRule',
      'prefer_master_detail_for_large',
      () => PreferMasterDetailForLargeRule(),
    );
  });
  group('Ui Ux Rules - Fixture Verification', () {
    final fixtures = [
      'require_responsive_breakpoints',
      'prefer_cached_paint_objects',
      'require_custom_painter_shouldrepaint',
      'require_currency_formatting_locale',
      'require_number_formatting_locale',
      'require_graphql_operation_names',
      'avoid_badge_without_meaning',
      'prefer_logger_over_print',
      'prefer_itemextent_when_known',
      'require_tab_state_preservation',
      'prefer_skeleton_over_spinner',
      'require_empty_results_state',
      'require_search_loading_indicator',
      'require_search_debounce',
      'require_pagination_loading_state',
      'require_pagination_error_recovery',
      'require_webview_progress_indicator',
      'avoid_loading_flash',
      'prefer_avatar_loading_placeholder',
      'prefer_adaptive_icons',
      'prefer_master_detail_for_large',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/ui_ux/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
