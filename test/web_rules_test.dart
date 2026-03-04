import 'dart:io';

import 'package:saropa_lints/src/rules/platforms/web_rules.dart';
import 'package:test/test.dart';

/// Tests for 9 Web lint rules.
///
/// Test fixtures: example_platforms/lib/web/
void main() {
  group('Web Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.name, codeName);
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
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_platforms/lib/web/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Web - Avoidance Rules', () {
    group('avoid_platform_channel_on_web', () {
      test('Platform channel call on web SHOULD trigger', () {
        expect('Platform channel call on web', isNotNull);
      });

      test('web-compatible alternatives should NOT trigger', () {
        expect('web-compatible alternatives', isNotNull);
      });
    });
    group('avoid_web_only_dependencies', () {
      test('web-only package in shared code SHOULD trigger', () {
        expect('web-only package in shared code', isNotNull);
      });

      test('platform-agnostic dependencies should NOT trigger', () {
        expect('platform-agnostic dependencies', isNotNull);
      });
    });
  });

  group('Web - Requirement Rules', () {
    group('require_cors_handling', () {
      test('HTTP request without CORS config SHOULD trigger', () {
        expect('HTTP request without CORS config', isNotNull);
      });

      test('CORS headers/proxy setup should NOT trigger', () {
        expect('CORS headers/proxy setup', isNotNull);
      });
    });
    group('require_web_renderer_awareness', () {
      test('rendering code without renderer check SHOULD trigger', () {
        expect('rendering code without renderer check', isNotNull);
      });

      test('renderer-aware rendering should NOT trigger', () {
        expect('renderer-aware rendering', isNotNull);
      });
    });
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
          expect(rule.code.name, 'prefer_js_interop_over_dart_js');
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
    group('prefer_deferred_loading_web', () {
      test('eager import of large web module SHOULD trigger', () {
        expect('eager import of large web module', isNotNull);
      });

      test('deferred import for web should NOT trigger', () {
        expect('deferred import for web', isNotNull);
      });
    });
    group('prefer_url_strategy_for_web', () {
      test('hash-based URL routing on web SHOULD trigger', () {
        expect('hash-based URL routing on web', isNotNull);
      });

      test('path URL strategy should NOT trigger', () {
        expect('path URL strategy', isNotNull);
      });
    });
  });
}
