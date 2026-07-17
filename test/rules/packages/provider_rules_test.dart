import 'dart:io';

import 'package:saropa_lints/src/rules/packages/provider_rules.dart';
import 'package:test/test.dart';

/// Tests for 27 Provider package lint rules.
///
/// These rules cover proper Provider/ChangeNotifier usage, Consumer/Selector
/// patterns, disposal, InheritedWidget requirements, and common anti-patterns.
///
/// Test fixtures: example_packages/lib/provider/*
void main() {
  group('Provider Rules - Rule Instantiation', () {
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
      'AvoidWatchInCallbacksRule',
      'avoid_watch_in_callbacks',
      () => AvoidWatchInCallbacksRule(),
    );
    testRule(
      'RequireUpdateShouldNotifyRule',
      'require_update_should_notify',
      () => RequireUpdateShouldNotifyRule(),
    );
    testRule(
      'AvoidProviderOfInBuildRule',
      'avoid_provider_of_in_build',
      () => AvoidProviderOfInBuildRule(),
    );
    testRule(
      'AvoidProviderRecreateRule',
      'avoid_provider_recreate',
      () => AvoidProviderRecreateRule(),
    );
    testRule(
      'AvoidProviderInWidgetRule',
      'avoid_provider_in_widget',
      () => AvoidProviderInWidgetRule(),
    );
    testRule(
      'AvoidChangeNotifierInWidgetRule',
      'avoid_change_notifier_in_widget',
      () => AvoidChangeNotifierInWidgetRule(),
    );
    testRule(
      'RequireProviderDisposeRule',
      'require_provider_dispose',
      () => RequireProviderDisposeRule(),
    );
    testRule(
      'RequireMultiProviderRule',
      'require_multi_provider',
      () => RequireMultiProviderRule(),
    );
    testRule(
      'AvoidNestedProvidersRule',
      'avoid_nested_providers',
      () => AvoidNestedProvidersRule(),
    );
    testRule(
      'PreferMultiProviderRule',
      'prefer_multi_provider',
      () => PreferMultiProviderRule(),
    );
    testRule(
      'AvoidInstantiatingInValueProviderRule',
      'avoid_instantiating_in_value_provider',
      () => AvoidInstantiatingInValueProviderRule(),
    );
    testRule(
      'DisposeProvidersRule',
      'dispose_provider_instances',
      () => DisposeProvidersRule(),
    );
    testRule(
      'PreferProviderExtensionsRule',
      'prefer_provider_extensions',
      () => PreferProviderExtensionsRule(),
    );
    testRule(
      'DisposeProvidedInstancesRule',
      'dispose_provided_instances',
      () => DisposeProvidedInstancesRule(),
    );
    testRule(
      'PreferNullableProviderTypesRule',
      'prefer_nullable_provider_types',
      () => PreferNullableProviderTypesRule(),
    );
    testRule(
      'PreferConsumerOverProviderOfRule',
      'prefer_consumer_over_provider_of',
      () => PreferConsumerOverProviderOfRule(),
    );
    testRule(
      'RequireProviderGenericTypeRule',
      'require_provider_generic_type',
      () => RequireProviderGenericTypeRule(),
    );
    testRule(
      'AvoidProviderInInitStateRule',
      'avoid_provider_in_init_state',
      () => AvoidProviderInInitStateRule(),
    );
    testRule(
      'PreferContextReadInCallbacksRule',
      'prefer_context_read_in_callbacks',
      () => PreferContextReadInCallbacksRule(),
    );
    testRule(
      'PreferProxyProviderRule',
      'prefer_proxy_provider',
      () => PreferProxyProviderRule(),
    );
    testRule(
      'RequireUpdateCallbackRule',
      'require_update_callback',
      () => RequireUpdateCallbackRule(),
    );
    testRule(
      'PreferSelectorOverConsumerRule',
      'prefer_selector_over_consumer',
      () => PreferSelectorOverConsumerRule(),
    );
    testRule(
      'AvoidProviderValueRebuildRule',
      'avoid_provider_value_rebuild',
      () => AvoidProviderValueRebuildRule(),
    );
    testRule(
      'PreferChangeNotifierProxyRule',
      'prefer_change_notifier_proxy',
      () => PreferChangeNotifierProxyRule(),
    );
    testRule(
      'PreferSelectorWidgetRule',
      'prefer_selector_widget',
      () => PreferSelectorWidgetRule(),
    );
    testRule(
      'PreferChangeNotifierProxyProviderRule',
      'prefer_change_notifier_proxy_provider',
      () => PreferChangeNotifierProxyProviderRule(),
    );
    testRule(
      'AvoidProviderListenFalseInBuildRule',
      'avoid_provider_listen_false_in_build',
      () => AvoidProviderListenFalseInBuildRule(),
    );
  });
  group('Provider Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/provider');

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
        final file = File(
          'example_packages/lib/provider/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
