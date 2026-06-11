import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/app_links_rules.dart';

/// Tests for 3 app_links lint rules.
///
/// Test fixtures: example_packages/lib/app_links/*
void main() {
  group('App Links Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule('AppLinksListenInBuildRule', 'app_links_listen_in_build',
        () => AppLinksListenInBuildRule());
    testRule('AppLinksUncaughtStreamErrorRule',
        'app_links_uncaught_stream_error',
        () => AppLinksUncaughtStreamErrorRule());
    testRule('AppLinksAvoidGetInitialLinkStringRule',
        'app_links_avoid_get_initial_link_string',
        () => AppLinksAvoidGetInitialLinkStringRule());
  });

  group('App Links Rules - Fixture Verification', () {
    final fixtures = [
      'app_links_listen_in_build',
      'app_links_uncaught_stream_error',
      'app_links_avoid_get_initial_link_string',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/app_links/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
