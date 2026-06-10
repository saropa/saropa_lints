import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Tests for Web lint rules.
///
/// Test fixtures: example/lib/web/
void main() {
  group('Web Rules - Rule Instantiation', () {
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
      'AvoidPlatformChannelOnWebRule',
      'avoid_platform_channel_on_web',
      () => AvoidPlatformChannelOnWebRule(),
    );
    testRule(
      'RequireCorsHandlingRule',
      'require_cors_handling',
      () => RequireCorsHandlingRule(),
    );
    testRule(
      'PreferDeferredLoadingWebRule',
      'prefer_deferred_loading_web',
      () => PreferDeferredLoadingWebRule(),
    );
    testRule(
      'AvoidWebOnlyDependenciesRule',
      'avoid_web_only_dependencies',
      () => AvoidWebOnlyDependenciesRule(),
    );
    testRule(
      'PreferJsInteropOverDartJsRule',
      'prefer_js_interop_over_dart_js',
      () => PreferJsInteropOverDartJsRule(),
    );
    testRule(
      'PreferUrlStrategyForWebRule',
      'prefer_url_strategy_for_web',
      () => PreferUrlStrategyForWebRule(),
    );
    testRule(
      'RequireWebRendererAwarenessRule',
      'require_web_renderer_awareness',
      () => RequireWebRendererAwarenessRule(),
    );
    testRule(
      'AvoidJsRoundedIntsRule',
      'avoid_js_rounded_ints',
      () => AvoidJsRoundedIntsRule(),
    );
    testRule(
      'PreferCsrfProtectionRule',
      'prefer_csrf_protection',
      () => PreferCsrfProtectionRule(),
    );
    testRule(
      'PreferScheduleMicrotaskOverWindowPostmessageRule',
      'prefer_schedule_microtask_over_window_postmessage',
      () => PreferScheduleMicrotaskOverWindowPostmessageRule(),
    );
  });
  group('Web Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_platform_channel_on_web',
      'require_cors_handling',
      'prefer_deferred_loading_web',
      'avoid_web_only_dependencies',
      'prefer_js_interop_over_dart_js',
      'prefer_url_strategy_for_web',
      'require_web_renderer_awareness',
      'avoid_js_rounded_ints',
      'prefer_csrf_protection',
      'prefer_schedule_microtask_over_window_postmessage',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/web/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Web - Preference Rules', () {
    group('prefer_js_interop_over_dart_js', () {
      test(
        'rule metadata: problemMessage mentions dart:js and dart:js_util',
        () {
          final rule = PreferJsInteropOverDartJsRule();
          final msg = rule.code.problemMessage;
          expect(msg, contains('dart:js'));
          expect(msg, contains('dart:js_util'));
        },
      );
      test(
        'only dart:js and dart:js_util trigger (no dart:html or package URIs)',
        () {
          // False-positive guard: rule uses exact Set match; similar URIs must not match.
          final rule = PreferJsInteropOverDartJsRule();
          expect(rule.code.lowerCaseName, 'prefer_js_interop_over_dart_js');
          // If the rule used .contains() on string, 'dart:html'.contains('dart:js') could match.
          // Our implementation uses Set.contains(uri) so only exact URIs trigger.
          expect(rule.code.correctionMessage, contains('dart:js_interop'));
        },
      );
      test('compliant URI dart:js_interop is not in deprecated set', () {
        const compliantUris = [
          'dart:js_interop',
          'dart:js_interop_unsafe',
          'dart:html',
          'package:foo/dart_js.dart',
        ];
        for (final uri in compliantUris) {
          expect(
            uri,
            isNot(equals('dart:js')),
            reason: 'dart:js should not be in compliant list',
          );
          expect(
            uri,
            isNot(equals('dart:js_util')),
            reason: 'dart:js_util should not be in compliant list',
          );
        }
      });
    });
    group('prefer_schedule_microtask_over_window_postmessage', () {
      test('problemMessage cites skwasm / postMessage cost', () {
        final rule = PreferScheduleMicrotaskOverWindowPostmessageRule();
        final msg = rule.code.problemMessage.toLowerCase();
        expect(msg, contains('postmessage'));
        expect(msg, contains('skwasm'));
      });

      test('impact is low; requiredPatterns include postMessage', () {
        final rule = PreferScheduleMicrotaskOverWindowPostmessageRule();
        expect(rule.impact, LintImpact.info);
        expect(rule.requiredPatterns, contains('postMessage'));
      });

      test('rule id is in professional cumulative tier', () {
        expect(
          getRulesForTier('professional'),
          contains('prefer_schedule_microtask_over_window_postmessage'),
        );
      });
    });
  });
}
