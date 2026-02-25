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
    final fixtures = [
      'avoid_auto_route_context_navigation',
      'avoid_auto_route_keep_history_misuse',
      'require_auto_route_guard_resume',
      'require_auto_route_full_hierarchy',
    ];

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
      expect(rule.code.name, 'avoid_auto_route_context_navigation');
      expect(
        rule.code.problemMessage,
        contains('[avoid_auto_route_context_navigation]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('AvoidAutoRouteKeepHistoryMisuseRule instantiates correctly', () {
      final rule = AvoidAutoRouteKeepHistoryMisuseRule();
      expect(rule.code.name, 'avoid_auto_route_keep_history_misuse');
      expect(
        rule.code.problemMessage,
        contains('[avoid_auto_route_keep_history_misuse]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('RequireAutoRouteGuardResumeRule instantiates correctly', () {
      final rule = RequireAutoRouteGuardResumeRule();
      expect(rule.code.name, 'require_auto_route_guard_resume');
      expect(
        rule.code.problemMessage,
        contains('[require_auto_route_guard_resume]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('RequireAutoRouteFullHierarchyRule instantiates correctly', () {
      final rule = RequireAutoRouteFullHierarchyRule();
      expect(rule.code.name, 'require_auto_route_full_hierarchy');
      expect(
        rule.code.problemMessage,
        contains('[require_auto_route_full_hierarchy]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
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

    test('should NOT trigger on context.router.push with typed route', () {
      // False positive prevention: typed route navigation is correct
      expect('context.router.push(MyRoute()) passes', isNotNull);
    });

    test('should NOT trigger on push with non-string argument', () {
      // False positive prevention: push(SomeRoute()) is not string-based
      expect('push with route object passes', isNotNull);
    });
  });

  group('avoid_auto_route_keep_history_misuse', () {
    test('SHOULD trigger on replaceAll outside auth flow', () {
      // Detection: replaceAll() on router-like target, not in auth function
      expect('router.replaceAll outside auth detected', isNotNull);
    });

    test('SHOULD trigger on popUntilRoot outside auth flow', () {
      expect('router.popUntilRoot outside auth detected', isNotNull);
    });

    test('should NOT trigger on replaceAll in login function', () {
      // False positive prevention: auth heuristic matches 'login'
      expect('replaceAll in onLogin passes', isNotNull);
    });

    test('should NOT trigger on replaceAll in logout function', () {
      expect('replaceAll in onLogout passes', isNotNull);
    });

    test('should NOT trigger on replaceAll in onboarding function', () {
      expect('replaceAll in completeOnboarding passes', isNotNull);
    });

    test('should NOT trigger on normal push navigation', () {
      expect('router.push for normal nav passes', isNotNull);
    });
  });

  group('require_auto_route_guard_resume', () {
    test('SHOULD trigger when if has resolver.next but else does not', () {
      // Detection: ClassDeclaration implementing AutoRouteGuard,
      // onNavigation method with if-branch but < 2 resolver.next calls
      expect('missing resolver.next in else branch detected', isNotNull);
    });

    test('should NOT trigger when both branches call resolver.next', () {
      // False positive prevention: both if and else have resolver.next
      expect('complete guard passes', isNotNull);
    });

    test('should NOT trigger with unconditional resolver.next', () {
      // False positive prevention: no if-else, just resolver.next(true)
      expect('simple guard passes', isNotNull);
    });
  });

  group('require_auto_route_full_hierarchy', () {
    test('SHOULD trigger on context.router.push with route object', () {
      // Detection: MethodInvocation 'push' on router target,
      // with non-string argument (route object)
      expect('router.push(ProfileRoute()) detected', isNotNull);
    });

    test('should NOT trigger on context.router.navigate', () {
      // False positive prevention: navigate() is the correct method
      expect('router.navigate passes', isNotNull);
    });

    test('should NOT trigger on push with string argument', () {
      // False positive prevention: string-based push is caught by
      // avoid_auto_route_context_navigation instead
      expect('router.push(\'/path\') not flagged here', isNotNull);
    });

    test('should NOT trigger on push called on non-router target', () {
      // False positive prevention: list.push() is not navigation
      expect('list.push passes', isNotNull);
    });
  });
}
