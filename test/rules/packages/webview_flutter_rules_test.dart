import 'dart:io';

import 'package:saropa_lints/src/rules/packages/webview_flutter_rules.dart';
import 'package:test/test.dart';

/// Instantiation-pin tests for the webview_flutter migration lint rule.
///
/// These tests verify:
///   1. The rule instantiates without error.
///   2. The rule code name matches the expected snake_case identifier.
///   3. The problem message starts with the `[rule_code]` prefix and is >200 chars.
///   4. A correction message is provided.
///
/// Test fixtures: example_packages/lib/webview_flutter/webview_flutter_fixture.dart
void main() {
  group('WebviewFlutter Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(
          rule.code.problemMessage.length,
          greaterThan(200),
          reason:
              'Problem message must exceed 200 chars (includes {v1} suffix)',
        );
        expect(rule.code.correctionMessage, isNotNull);
        expect(
          rule.code.correctionMessage,
          isNotEmpty,
          reason: 'Correction message must not be empty',
        );
      });
    }

    testRule(
      'AvoidPreV4WebviewWidgetRule',
      'avoid_pre_v4_webview_widget',
      () => AvoidPreV4WebviewWidgetRule(),
    );
  });

  group('WebviewFlutter Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/webview_flutter');

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
          'example_packages/lib/webview_flutter/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('WebviewFlutter Rules - Metadata', () {
    test('AvoidPreV4WebviewWidgetRule has no fix generators', () {
      final rule = AvoidPreV4WebviewWidgetRule();
      // Report-only: the WebView → WebViewController + WebViewWidget rewrite
      // is structural and cannot be automated.
      expect(rule.fixGenerators, isEmpty);
    });

    test('AvoidPreV4WebviewWidgetRule severity is WARNING', () {
      final rule = AvoidPreV4WebviewWidgetRule();
      expect(rule.code.severity.displayName.toLowerCase(), 'warning');
    });

    test('AvoidPreV4WebviewWidgetRule tags include packages', () {
      final rule = AvoidPreV4WebviewWidgetRule();
      expect(rule.tags, contains('packages'));
    });
  });
}
