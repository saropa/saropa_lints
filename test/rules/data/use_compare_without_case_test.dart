// Behavior tests for use_compare_without_case.
//
// These run the rule class directly through the resolved-rule harness
// (test/support/resolved_rule_harness.dart), which registers the rule's node
// processors against a fully resolved unit. That bypasses tier/CLI selection
// entirely, so the rule's opt-in (stylistic) status is irrelevant here — an
// earlier version of this file claimed the opposite and shipped
// metadata-only assertions, which meant none of the fixture's expect_lint
// markers were ever executed by CI and a false negative could ship silently.
library;

import 'package:saropa_lints/src/rules/data/use_compare_without_case_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart' show RuleStatus;
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Runs the rule over [code] and returns the distinct rule codes reported.
Future<Set<String>> _codes(String code) =>
    reportedRuleCodes(UseCompareWithoutCaseRule(), code);

const String _rule = 'use_compare_without_case';

void main() {
  // Rule Instantiation: metadata smoke test.
  group('$_rule metadata', () {
    test('code, message prefix, length and correction message', () {
      final rule = UseCompareWithoutCaseRule();
      expect(rule.code.lowerCaseName, _rule);
      expect(rule.code.problemMessage, contains('[$_rule]'));
      // Project convention requires problem messages >200 chars; a
      // greaterThan(50) threshold would silently pass a message shrunk well
      // below the required length.
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('rule status is beta (opt-in, pending real-world tuning)', () {
      expect(UseCompareWithoutCaseRule().ruleStatus, RuleStatus.beta);
    });

    test('requires type resolution to compare String static types', () {
      expect(UseCompareWithoutCaseRule().usesTypeResolution, isTrue);
    });
  });

  group('$_rule BAD cases', () {
    test('fires on == against a literal with a non-constant operand', () async {
      expect(
        await _codes('''
bool isAdminRole(String role) => role == 'admin';
'''),
        contains(_rule),
      );
    });

    test('fires on the != form of the same comparison', () async {
      expect(
        await _codes('''
bool isNotAdminRole(String role) => role != 'admin';
'''),
        contains(_rule),
      );
    });

    test('fires on compareTo(...) == 0', () async {
      expect(
        await _codes('''
bool same(String a, String b) => a.compareTo(b) == 0;
'''),
        contains(_rule),
      );
    });

    test('fires on the reversed 0 == compareTo(...) operand order', () async {
      expect(
        await _codes('''
bool same(String a, String b) => 0 == a.compareTo(b);
'''),
        contains(_rule),
      );
    });

    test('fires on compareTo(...) != 0', () async {
      expect(
        await _codes('''
bool differs(String a, String b) => a.compareTo(b) != 0;
'''),
        contains(_rule),
      );
    });

    test('fires on a nullable String operand', () async {
      expect(
        await _codes('''
bool isAdminRole(String? role) => role == 'admin';
'''),
        contains(_rule),
      );
    });

    // The regression this suite exists for: before rule v2 a normalization
    // call on EITHER side exempted the comparison, so this mismatched pair —
    // true only for strings with no cased characters at all — passed silently.
    test('fires on mismatched normalization (lower vs upper)', () async {
      expect(
        await _codes('''
bool sameEmail(String typed, String stored) =>
    typed.toLowerCase() == stored.toUpperCase();
'''),
        contains(_rule),
      );
    });

    test('fires on mismatched normalization in the opposite order', () async {
      expect(
        await _codes('''
bool sameEmail(String typed, String stored) =>
    typed.toUpperCase() == stored.toLowerCase();
'''),
        contains(_rule),
      );
    });

    test('fires when only one side is normalized and the other is a '
        'non-constant variable', () async {
      expect(
        await _codes('''
bool sameEmail(String typed, String stored) => typed.toLowerCase() == stored;
'''),
        contains(_rule),
      );
    });

    test('fires when normalized against a literal in the wrong case', () async {
      expect(
        await _codes('''
bool isAdminRole(String role) => role.toLowerCase() == 'Admin';
'''),
        contains(_rule),
      );
    });

    test('fires when upper-normalized against a lowercase literal', () async {
      expect(
        await _codes('''
bool isAdminRole(String role) => role.toUpperCase() == 'admin';
'''),
        contains(_rule),
      );
    });

    test('fires when only ONE side is a constant', () async {
      expect(
        await _codes('''
const String kRoute = 'settings_page';
bool isRoute(String route) => route == kRoute;
'''),
        contains(_rule),
      );
    });

    // Documented false positive, locked in so a future enum-aware widening of
    // `_isConstantString` is a deliberate change rather than a silent drift.
    test('fires on enum.name compared against a literal tag', () async {
      expect(
        await _codes('''
enum Status { active, inactive }
bool isActive(Status s) => s.name == 'active';
'''),
        contains(_rule),
      );
    });
  });

  group('$_rule GOOD cases', () {
    test('does NOT fire when both sides use toLowerCase()', () async {
      expect(
        await _codes('''
bool sameEmail(String typed, String stored) =>
    typed.toLowerCase() == stored.toLowerCase();
'''),
        isEmpty,
      );
    });

    test('does NOT fire when both sides use toUpperCase()', () async {
      expect(
        await _codes('''
bool sameEmail(String typed, String stored) =>
    typed.toUpperCase() != stored.toUpperCase();
'''),
        isEmpty,
      );
    });

    test(
      'does NOT fire when normalized against a matching-case literal',
      () async {
        expect(
          await _codes('''
bool isAdminRole(String role) => role.toLowerCase() == 'admin';
'''),
          isEmpty,
        );
      },
    );

    test(
      'does NOT fire when upper-normalized against an uppercase literal',
      () async {
        expect(
          await _codes('''
bool isAdminRole(String role) => role.toUpperCase() != 'ADMIN';
'''),
          isEmpty,
        );
      },
    );

    test('does NOT fire on normalized compareTo(...) == 0', () async {
      expect(
        await _codes('''
bool same(String a, String b) =>
    a.toUpperCase().compareTo(b.toUpperCase()) == 0;
'''),
        isEmpty,
      );
    });

    test('does NOT fire when BOTH sides are our own const strings', () async {
      expect(
        await _codes('''
const String kRouteA = 'settings_page';
const String kRouteB = 'settings_page';
bool sameRoute() => kRouteA == kRouteB;
'''),
        isEmpty,
      );
    });

    test('does NOT fire on two string literals', () async {
      expect(
        await _codes('''
bool literalsMatch() => 'abc' == 'xyz';
'''),
        isEmpty,
      );
    });

    test('does NOT fire on a ClassName.constField operand pair', () async {
      expect(
        await _codes('''
const String kRouteA = 'settings_page';
class RouteNames {
  static const String settings = 'settings_page';
}
bool sameRoute() => RouteNames.settings == kRouteA;
'''),
        isEmpty,
      );
    });

    test('does NOT fire on non-String operands', () async {
      expect(
        await _codes('''
bool sameCount(int a, int b) => a == b;
'''),
        isEmpty,
      );
    });

    test(
      'does NOT fire on compareTo used for ordering rather than equality',
      () async {
        expect(
          await _codes('''
bool isBefore(String a, String b) => a.compareTo(b) < 0;
'''),
          isEmpty,
        );
      },
    );

    test('does NOT fire on dynamic-typed map access', () async {
      expect(
        await _codes('''
bool isSuccess(Map<String, dynamic> json) => json['type'] == 'success';
'''),
        isEmpty,
      );
    });

    // Tightening guard: a same-named method on a non-String receiver is not
    // String case normalization, so it must not exempt the comparison. Here
    // BOTH operands are plain Strings and neither is normalized, so the
    // unrelated helper name must not suppress the report.
    test('an unrelated toLowerCase() on a non-String receiver does not '
        'exempt the comparison', () async {
      expect(
        await _codes('''
class Locale {
  const Locale();
  String toLowerCase() => 'x';
}
bool check(String value, String other) =>
    value == other && const Locale().toLowerCase().isNotEmpty;
'''),
        contains(_rule),
      );
    });
  });
}
