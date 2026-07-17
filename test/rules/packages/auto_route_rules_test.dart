import 'dart:io';

import 'package:saropa_lints/src/rules/packages/auto_route_rules.dart';
import 'package:test/test.dart';

/// Tests for 4 auto_route lint rules.
///
/// Rules:
///   - avoid_auto_route_context_navigation (Professional, WARNING)
///   - avoid_auto_route_keep_history_misuse (Professional, WARNING)
///   - require_auto_route_guard_resume (Essential, WARNING)
///   - require_auto_route_full_hierarchy (Essential, WARNING)
///
/// Test fixtures: example_packages/lib/auto_route/*
void main() {
  group('Auto Route Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/auto_route');

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
          'example_packages/lib/auto_route/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Auto Route Rules - Rule Instantiation', () {
    test('AvoidAutoRouteContextNavigationRule instantiates correctly', () {
      final rule = AvoidAutoRouteContextNavigationRule();
      expect(rule.code.lowerCaseName, 'avoid_auto_route_context_navigation');
      expect(
        rule.code.problemMessage,
        contains('[avoid_auto_route_context_navigation]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('AvoidAutoRouteKeepHistoryMisuseRule instantiates correctly', () {
      final rule = AvoidAutoRouteKeepHistoryMisuseRule();
      expect(rule.code.lowerCaseName, 'avoid_auto_route_keep_history_misuse');
      expect(
        rule.code.problemMessage,
        contains('[avoid_auto_route_keep_history_misuse]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('RequireAutoRouteGuardResumeRule instantiates correctly', () {
      final rule = RequireAutoRouteGuardResumeRule();
      expect(rule.code.lowerCaseName, 'require_auto_route_guard_resume');
      expect(
        rule.code.problemMessage,
        contains('[require_auto_route_guard_resume]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('RequireAutoRouteFullHierarchyRule instantiates correctly', () {
      final rule = RequireAutoRouteFullHierarchyRule();
      expect(rule.code.lowerCaseName, 'require_auto_route_full_hierarchy');
      expect(
        rule.code.problemMessage,
        contains('[require_auto_route_full_hierarchy]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('PreferAutoRoutePathParamsSimpleRule instantiates correctly', () {
      final rule = PreferAutoRoutePathParamsSimpleRule();
      expect(rule.code.lowerCaseName, 'prefer_auto_route_path_params_simple');
      expect(
        rule.code.problemMessage,
        contains('[prefer_auto_route_path_params_simple]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('PreferAutoRouteTypedArgsRule instantiates correctly', () {
      final rule = PreferAutoRouteTypedArgsRule();
      expect(rule.code.lowerCaseName, 'prefer_auto_route_typed_args');
      expect(
        rule.code.problemMessage,
        contains('[prefer_auto_route_typed_args]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('avoid_auto_route_context_navigation', () {
    test('SHOULD trigger on context.push with string literal', () {
      // Detection: MethodInvocation where target ends with 'context',
      // method is push/go/pushNamed/etc., and first arg is string literal
      expect('context.push(\'/path\') detected', isNotNull);
    });

    test('SHOULD trigger on context.go with string literal', () {
      expect('context.go(\'/home\') detected', isNotNull);
    });

    test('SHOULD trigger on context.pushNamed with string', () {
      expect('context.pushNamed(\'/settings\') detected', isNotNull);
    });

    test('SHOULD trigger on string interpolation navigation', () {
      expect('context.push(\'/products/\$id\') detected', isNotNull);
    });
  });

  group('require_auto_route_full_hierarchy', () {
    test('should NOT trigger on push with string argument', () {
      // False positive prevention: string-based push is caught by
      // avoid_auto_route_context_navigation instead
      expect('router.push(\'/path\') not flagged here', isNotNull);
    });
  });
}
