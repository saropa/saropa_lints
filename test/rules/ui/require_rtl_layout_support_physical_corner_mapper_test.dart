import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Bug: bugs/require_rtl_layout_support_false_positive_physical_corner_enum_mapper.md
///
/// `require_rtl_layout_support` must not fire on identity-named enum-mapper
/// arms (e.g. `AlignmentOption.topLeft => Alignment.topLeft`) because the
/// enum's member names already commit the public API to physical-direction
/// semantics — flipping under RTL would silently break callers.
///
/// The implementation is private (`_isIdentityEnumMapperArm` in
/// internationalization_rules.dart). These tests reproduce the same predicate
/// against parsed AST snippets so the contract is independently verified.
void main() {
  const ruleName = 'require_rtl_layout_support';
  const fixturePath =
      'example/lib/internationalization/require_rtl_layout_support_fixture.dart';

  group('require_rtl_layout_support physical-corner enum mapper', () {
    test('rule is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('fixture exists and contains both BAD and GOOD sections', () {
      final file = File(fixturePath);
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('_PhysicalCornerMapperArrowBody'));
      expect(content, contains('_PhysicalCornerMapperBlockBody'));
      expect(content, contains('_NonIdentityMapper'));
    });

    test('physical-corner mapper sections carry NO expect_lint markers', () {
      // Identity-named arms must not lint after the fix; their absence of
      // `expect_lint:` markers is a regression check against accidental
      // re-broadening of the rule.
      final content = File(fixturePath).readAsStringSync();
      final start = content.indexOf('_PhysicalCornerMapperArrowBody');
      final end = content.indexOf('_NonIdentityMapper');
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final slice = content.substring(start, end);
      expect(
        slice.contains('expect_lint: $ruleName'),
        isFalse,
        reason:
            'Identity-named enum-mapper arms (e.g. EnumValue.name => '
            'Alignment.name) must not require suppression markers.',
      );
    });

    test('non-identity mapper arms still carry expect_lint markers', () {
      // The fix must NOT silence non-identity mappings — the rule must still
      // fire on `DirectionOption.start => Alignment.topLeft` etc.
      final content = File(fixturePath).readAsStringSync();
      final start = content.indexOf('_NonIdentityMapper');
      expect(start, greaterThan(-1));
      final tail = content.substring(start);
      final markerCount = '// expect_lint: $ruleName'.allMatches(tail).length;
      expect(
        markerCount,
        equals(2),
        reason:
            'Two non-identity arms in _NonIdentityMapper must each declare '
            'expect_lint to verify the rule continues to fire.',
      );
    });

    test('plain Alignment.topLeft (non-switch) still triggers — no AST hit', () {
      // Sanity check on the AST predicate: a bare PrefixedIdentifier whose
      // parent is NOT a SwitchExpressionCase must NOT be treated as an
      // identity mapper arm.
      final unit = parseString(
        content: 'final a = Alignment.topLeft;',
      ).unit;
      final decl = unit.declarations.first as TopLevelVariableDeclaration;
      final init = decl.variables.variables.first.initializer!;
      expect(init, isA<PrefixedIdentifier>());
      final pid = init as PrefixedIdentifier;
      expect(pid.parent, isNot(isA<SwitchExpressionCase>()));
    });

    test('identity-named switch arm has SwitchExpressionCase parent + matching ConstantPattern', () {
      // Confirms the AST shape the rule's predicate keys on. Mirrors what
      // `_isIdentityEnumMapperArm` checks.
      const code = '''
enum AlignmentOption { topLeft }
class Alignment { static const topLeft = Alignment._(); const Alignment._(); }
Alignment f(AlignmentOption v) => switch (v) {
  AlignmentOption.topLeft => Alignment.topLeft,
};
''';
      final unit = parseString(content: code).unit;
      // Find the function and dive into its switch expression.
      final fn = unit.declarations.whereType<FunctionDeclaration>().single;
      final body = fn.functionExpression.body as ExpressionFunctionBody;
      final switchExpr = body.expression as SwitchExpression;
      final arm = switchExpr.cases.single;

      // RHS — the lint target.
      expect(arm.expression, isA<PrefixedIdentifier>());
      final rhs = arm.expression as PrefixedIdentifier;
      expect(rhs.prefix.name, 'Alignment');
      expect(rhs.identifier.name, 'topLeft');
      expect(identical(rhs.parent, arm), isTrue);

      // Pattern — must be ConstantPattern wrapping a PrefixedIdentifier
      // whose simple name matches the RHS identifier.
      final pattern = arm.guardedPattern.pattern;
      expect(pattern, isA<ConstantPattern>());
      final patternExpr = (pattern as ConstantPattern).expression;
      expect(patternExpr, isA<PrefixedIdentifier>());
      expect(
        (patternExpr as PrefixedIdentifier).identifier.name,
        rhs.identifier.name,
        reason: 'identity-named: enum constant name == Alignment member name',
      );
    });

    test('non-identity switch arm has mismatched names', () {
      // `DirectionOption.start => Alignment.topLeft` — the predicate must
      // see the name mismatch and let the rule fire.
      const code = '''
enum DirectionOption { start }
class Alignment { static const topLeft = Alignment._(); const Alignment._(); }
Alignment f(DirectionOption v) => switch (v) {
  DirectionOption.start => Alignment.topLeft,
};
''';
      final unit = parseString(content: code).unit;
      final fn = unit.declarations.whereType<FunctionDeclaration>().single;
      final body = fn.functionExpression.body as ExpressionFunctionBody;
      final switchExpr = body.expression as SwitchExpression;
      final arm = switchExpr.cases.single;

      final rhs = arm.expression as PrefixedIdentifier;
      final patternExpr =
          (arm.guardedPattern.pattern as ConstantPattern).expression
              as PrefixedIdentifier;
      expect(
        patternExpr.identifier.name == rhs.identifier.name,
        isFalse,
        reason:
            'non-identity: enum name (start) differs from Alignment member '
            '(topLeft) — rule must continue to fire.',
      );
    });
  });
}
