import 'dart:io';

import 'package:saropa_lints/src/rules/ui/navigation_rules.dart';
import 'package:test/test.dart';

/// Tests for 36 Navigation lint rules.
///
/// Test fixtures: example/lib/navigation/*
// GoRouter, Navigator, and route parameter patterns in example/lib/navigation.
void main() {
  group('Navigation Rules - Rule Instantiation', () {
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
      'RequireUnknownRouteHandlerRule',
      'require_unknown_route_handler',
      () => RequireUnknownRouteHandlerRule(),
    );
    testRule(
      'AvoidContextAfterNavigationRule',
      'avoid_context_after_navigation',
      () => AvoidContextAfterNavigationRule(),
    );
    testRule(
      'RequireRouteTransitionConsistencyRule',
      'require_route_transition_consistency',
      () => RequireRouteTransitionConsistencyRule(),
    );
    testRule(
      'AvoidNavigatorPushUnnamedRule',
      'avoid_navigator_push_unnamed',
      () => AvoidNavigatorPushUnnamedRule(),
    );
    testRule(
      'RequireRouteGuardsRule',
      'require_route_guards',
      () => RequireRouteGuardsRule(),
    );
    testRule(
      'AvoidCircularRedirectsRule',
      'avoid_circular_redirects',
      () => AvoidCircularRedirectsRule(),
    );
    testRule(
      'AvoidPopWithoutResultRule',
      'avoid_pop_without_result',
      () => AvoidPopWithoutResultRule(),
    );
    testRule(
      'PreferShellRouteForPersistentUiRule',
      'prefer_shell_route_for_persistent_ui',
      () => PreferShellRouteForPersistentUiRule(),
    );
    testRule(
      'RequireDeepLinkFallbackRule',
      'require_deep_link_fallback',
      () => RequireDeepLinkFallbackRule(),
    );
    testRule(
      'AvoidDeepLinkSensitiveParamsRule',
      'avoid_deep_link_sensitive_params',
      () => AvoidDeepLinkSensitiveParamsRule(),
    );
    testRule(
      'PreferTypedRouteParamsRule',
      'prefer_typed_route_params',
      () => PreferTypedRouteParamsRule(),
    );
    testRule(
      'RequireStepperValidationRule',
      'require_stepper_validation',
      () => RequireStepperValidationRule(),
    );
    testRule(
      'RequireStepCountIndicatorRule',
      'require_step_count_indicator',
      () => RequireStepCountIndicatorRule(),
    );
    testRule(
      'AvoidGoRouterInlineCreationRule',
      'avoid_go_router_inline_creation',
      () => AvoidGoRouterInlineCreationRule(),
    );
    testRule(
      'RequireGoRouterErrorHandlerRule',
      'require_go_router_error_handler',
      () => RequireGoRouterErrorHandlerRule(),
    );
    testRule(
      'RequireGoRouterRefreshListenableRule',
      'require_go_router_refresh_listenable',
      () => RequireGoRouterRefreshListenableRule(),
    );
    testRule(
      'AvoidGoRouterStringPathsRule',
      'avoid_go_router_string_paths',
      () => AvoidGoRouterStringPathsRule(),
    );
    testRule(
      'PreferGoRouterRedirectAuthRule',
      'prefer_go_router_redirect_auth',
      () => PreferGoRouterRedirectAuthRule(),
    );
    testRule(
      'RequireGoRouterTypedParamsRule',
      'require_go_router_typed_params',
      () => RequireGoRouterTypedParamsRule(),
    );
    testRule(
      'PreferGoRouterExtraTypedRule',
      'prefer_go_router_extra_typed',
      () => PreferGoRouterExtraTypedRule(),
    );
    testRule(
      'PreferMaybePopRule',
      'prefer_maybe_pop',
      () => PreferMaybePopRule(),
    );
    testRule(
      'PreferUrlLauncherUriOverStringRule',
      'prefer_url_launcher_uri_over_string',
      () => PreferUrlLauncherUriOverStringRule(),
    );
    testRule(
      'AvoidGoRouterPushReplacementConfusionRule',
      'avoid_go_router_push_replacement_confusion',
      () => AvoidGoRouterPushReplacementConfusionRule(),
    );
    testRule(
      'RequireUrlLauncherEncodingRule',
      'require_url_launcher_encoding',
      () => RequireUrlLauncherEncodingRule(),
    );
    testRule(
      'AvoidNestedRoutesWithoutParentRule',
      'avoid_nested_routes_without_parent',
      () => AvoidNestedRoutesWithoutParentRule(),
    );
    testRule(
      'PreferShellRouteSharedLayoutRule',
      'prefer_shell_route_shared_layout',
      () => PreferShellRouteSharedLayoutRule(),
    );
    testRule(
      'RequireStatefulShellRouteTabsRule',
      'require_stateful_shell_route_tabs',
      () => RequireStatefulShellRouteTabsRule(),
    );
    testRule(
      'RequireGoRouterFallbackRouteRule',
      'require_go_router_fallback_route',
      () => RequireGoRouterFallbackRouteRule(),
    );
    testRule(
      'PreferRouteSettingsNameRule',
      'prefer_route_settings_name',
      () => PreferRouteSettingsNameRule(),
    );
    testRule(
      'AvoidNavigatorContextIssueRule',
      'avoid_navigator_context_issue',
      () => AvoidNavigatorContextIssueRule(),
    );
    testRule(
      'RequirePopResultTypeRule',
      'require_pop_result_type',
      () => RequirePopResultTypeRule(),
    );
    testRule(
      'AvoidPushReplacementMisuseRule',
      'avoid_push_replacement_misuse',
      () => AvoidPushReplacementMisuseRule(),
    );
    testRule(
      'AvoidNestedNavigatorsMisuseRule',
      'avoid_nested_navigators_misuse',
      () => AvoidNestedNavigatorsMisuseRule(),
    );
    testRule(
      'RequireDeepLinkTestingRule',
      'require_deep_link_testing',
      () => RequireDeepLinkTestingRule(),
    );
    testRule(
      'RequireNavigationResultHandlingRule',
      'require_navigation_result_handling',
      () => RequireNavigationResultHandlingRule(),
    );
    testRule(
      'PreferGoRouterRedirectRule',
      'prefer_go_router_redirect',
      () => PreferGoRouterRedirectRule(),
    );
    testRule(
      'RequireAutoRoutePageSuffixRule',
      'require_auto_route_page_suffix',
      () => RequireAutoRoutePageSuffixRule(),
    );
    testRule(
      'PreferNamedRoutesForDeepLinksRule',
      'prefer_named_routes_for_deep_links',
      () => PreferNamedRoutesForDeepLinksRule(),
    );
  });
  group('Navigation Rules - Fixture Verification', () {
    final fixtures = [
      'require_unknown_route_handler',
      'avoid_context_after_navigation',
      'require_route_transition_consistency',
      'avoid_navigator_push_unnamed',
      'require_route_guards',
      'avoid_circular_redirects',
      'avoid_pop_without_result',
      'prefer_shell_route_for_persistent_ui',
      'require_deep_link_fallback',
      'avoid_deep_link_sensitive_params',
      'prefer_typed_route_params',
      'require_stepper_validation',
      'require_step_count_indicator',
      'avoid_go_router_inline_creation',
      'require_go_router_error_handler',
      'require_go_router_refresh_listenable',
      'avoid_go_router_string_paths',
      'prefer_go_router_redirect_auth',
      'require_go_router_typed_params',
      'prefer_go_router_extra_typed',
      'prefer_maybe_pop',
      'prefer_named_routes_for_deep_links',
      'prefer_url_launcher_uri_over_string',
      'avoid_go_router_push_replacement_confusion',
      'require_url_launcher_encoding',
      'avoid_nested_routes_without_parent',
      'prefer_shell_route_shared_layout',
      'require_stateful_shell_route_tabs',
      'require_go_router_fallback_route',
      'prefer_route_settings_name',
      'avoid_navigator_context_issue',
      'require_pop_result_type',
      'avoid_push_replacement_misuse',
      'avoid_nested_navigators_misuse',
      'require_deep_link_testing',
      'require_navigation_result_handling',
      'prefer_go_router_redirect',
      'prefer_go_router_builder',
      'prefer_branch_io_or_firebase_links',
      'require_auto_route_page_suffix',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/navigation/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture checks while migrating to analyzer-backed behavior tests.
}
