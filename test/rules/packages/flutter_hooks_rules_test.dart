import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/flutter_hooks_rules.dart';

/// Tests for 5 Flutter Hooks lint rules.
///
/// Test fixtures: example_packages/lib/flutter_hooks/*
void main() {
  group('Flutter Hooks Rules - Rule Instantiation', () {
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
      'AvoidHooksOutsideBuildRule',
      'avoid_hooks_outside_build',
      () => AvoidHooksOutsideBuildRule(),
    );

    testRule(
      'AvoidConditionalHooksRule',
      'avoid_conditional_hooks',
      () => AvoidConditionalHooksRule(),
    );

    testRule(
      'AvoidUnnecessaryHookWidgetsRule',
      'avoid_unnecessary_hook_widgets',
      () => AvoidUnnecessaryHookWidgetsRule(),
    );

    testRule(
      'PreferUseCallbackRule',
      'prefer_use_callback',
      () => PreferUseCallbackRule(),
    );

    testRule(
      'AvoidMisusedHooksRule',
      'avoid_misused_hooks',
      () => AvoidMisusedHooksRule(),
    );
  });

  group('Flutter Hooks Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_hooks_outside_build',
      'avoid_conditional_hooks',
      'avoid_unnecessary_hook_widgets',
      'prefer_use_callback',
      'avoid_misused_hooks',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/flutter_hooks/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
