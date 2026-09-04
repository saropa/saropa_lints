// Tests for the `duplicate_value` lint rule.
//
// Fixture: example/lib/control_flow/duplicate_value_fixture.dart
//
// This suite deliberately does MORE than pin metadata. The rule's two most
// bug-prone parts are documented in the source as regression guards for a
// prior paren-flattening bug:
//   * `_collectOperands` must call `unParenthesized` before recursing, so a
//     same-operator chain split across grouping parens (`a || (b || a)`) is
//     flattened into one chain rather than treated as an opaque leaf.
//   * The same-operator-parent skip must unwrap `ParenthesizedExpression`
//     ancestors, so the inner `(b || a)` is not evaluated as an independent
//     root in isolation from the `a` outside the parens.
// Neither guard is provable by asserting on `code.problemMessage`. Without
// executing the rule a refactor could reintroduce the bug with CI green, so
// every behavioral claim below runs the real rule against real source via
// the resolved harness (`reportedRuleCodes`), the same pattern used by the
// sibling flow_fp_test.dart in this directory.
library;

import 'dart:io';

import 'package:saropa_lints/src/rules/flow/duplicate_value_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Wraps [expression] in a resolvable top-level function so the harness
/// can produce a fully resolved unit. Kept in one place so every case below
/// differs ONLY in the boolean expression under test — that is the variable
/// the tests are actually isolating.
String _fixture(String expression) =>
    '''
bool check(int a, int b, int c) {
  return $expression;
}
''';

/// True when the rule reported at least one `duplicate_value` diagnostic for
/// the given boolean [expression]. Collapsing to a bool keeps each test a
/// single readable assertion about firing vs. not firing.
Future<bool> _fires(String expression) async {
  final Set<String> codes = await reportedRuleCodes(
    DuplicateValueRule(),
    _fixture(expression),
  );
  return codes.contains('duplicate_value');
}

void main() {
  group('DuplicateValueRule - Rule Instantiation', () {
    // Metadata pins: the `[rule_name]` prefix and a non-null correctionMessage
    // are hard project contracts enforced across rule batches; length guards
    // against a message being truncated to an unhelpful one-liner.
    test('DuplicateValueRule', () {
      final rule = DuplicateValueRule();
      expect(rule.code.lowerCaseName, 'duplicate_value');
      expect(rule.code.problemMessage, contains('[duplicate_value]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('DuplicateValueRule - Detection (positive)', () {
    // The simplest possible duplicate: two identical operands, adjacent, one
    // operator. If this ever stops firing the rule is entirely dead.
    test('fires on adjacent && duplicate', () async {
      expect(await _fires('a == 1 && a == 1'), isTrue);
    });

    test('fires on adjacent || duplicate', () async {
      expect(await _fires('a == 1 || a == 1'), isTrue);
    });

    // Non-adjacent duplicates prove the rule flattens the whole chain into a
    // seen-set rather than only comparing immediate left/right siblings — a
    // naive pairwise implementation would pass the adjacent cases and miss
    // this one.
    test('fires on non-adjacent duplicate in a longer && chain', () async {
      expect(await _fires('a == 1 && b == 2 && a == 1'), isTrue);
    });

    // REGRESSION GUARD (paren flattening). `(b || a)` must be unwrapped by
    // `_collectOperands` so the inner `a == 1` is compared against the `a == 1`
    // outside the parens. If `unParenthesized` is dropped, the parenthesized
    // group becomes one opaque operand and this silently stops firing.
    test('fires on duplicate split across grouping parens', () async {
      expect(await _fires('a == 1 || (b == 2 || a == 1)'), isTrue);
    });

    // REGRESSION GUARD (same-operator-parent skip). The inner `(b || a)` is
    // itself a `||` BinaryExpression and IS visited by the AST walk. Its
    // parent chain is ParenthesizedExpression -> BinaryExpression(`||`), so
    // the skip must unwrap the parens and bail out; if it does not, the inner
    // node is treated as an independent root, its two distinct operands are
    // compared in isolation, and the duplicate that only exists across the
    // paren boundary is reported from the wrong node (or double-reported).
    // Exactly one diagnostic proves the skip and the flattening agree.
    test('reports the paren-split duplicate exactly once', () async {
      final List<HarnessDiagnostic> diags = await runRuleResolved(
        DuplicateValueRule(),
        _fixture('a == 1 || (b == 2 || a == 1)'),
      );
      expect(
        diags.where((d) => d.ruleName == 'duplicate_value').length,
        1,
        reason:
            'A duplicate inside a same-operator chain must be reported once, '
            'not once per nesting level of the chain.',
      );
    });

    // Long chains are visited at every nesting level; the same-operator-parent
    // skip is what stops N-1 redundant reports. Pinning the exact count here
    // catches a regression that would otherwise only look like noise.
    test('reports one diagnostic per duplicate in a deep chain', () async {
      final List<HarnessDiagnostic> diags = await runRuleResolved(
        DuplicateValueRule(),
        _fixture('a == 1 && b == 2 && c == 3 && a == 1'),
      );
      expect(diags.where((d) => d.ruleName == 'duplicate_value').length, 1);
    });
  });

  group(
    'DuplicateValueRule - Detection (negative / false-positive guards)',
    () {
      // Distinct comparisons on the same receiver: the most common near-miss
      // shape. Text comparison of FULL operands (never a substring check) is
      // what keeps this silent.
      test('does NOT fire on distinct comparisons of one variable', () async {
        expect(await _fires('a == 1 || a == 2'), isFalse);
      });

      // Different receivers compared to the same literal. A substring-based
      // implementation matching on `== 1` would falsely fire here.
      test(
        'does NOT fire on different receivers with the same literal',
        () async {
          expect(await _fires('a == 1 && b == 1'), isFalse);
        },
      );

      // Mixed operators: `_collectOperands` refuses to descend into a nested
      // BinaryExpression whose operator differs, so each `&&` group stays an
      // opaque operand of the outer `||`. The shared `a == 1` fragment lives
      // inside two DIFFERENT groups and must not be merged into one flat list —
      // if flattening ignored the operator, this would falsely fire.
      test(
        'does NOT fire across mixed operators with a shared fragment',
        () async {
          expect(
            await _fires('(a == 1 && b == 2) || (a == 1 && c == 3)'),
            isFalse,
          );
        },
      );

      // A same-operator chain split across parens whose operands are all
      // distinct once flattened. This is the counterpart to the positive paren
      // case: flattening must not itself invent duplicates.
      test(
        'does NOT fire on a paren-split chain of distinct operands',
        () async {
          expect(await _fires('a == 1 || (b == 2 || c == 3)'), isFalse);
        },
      );

      // Property access on different receivers — `.x == 1` is a shared suffix,
      // but the full operand sources (`o1.x == 1` vs `o2.x == 1`) differ.
      test('does NOT fire on the same field of different receivers', () async {
        final Set<String> codes = await reportedRuleCodes(
          DuplicateValueRule(),
          '''
class Box {
  Box(this.x);
  final int x;
}

bool check(Box o1, Box o2) {
  return o1.x == 1 && o2.x == 1;
}
''',
        );
        expect(codes.contains('duplicate_value'), isFalse);
      });
    },
  );

  group('DuplicateValueRule - Documented tradeoffs', () {
    // An ENTIRE `&&` group repeated as both operands of a `||` IS a genuine
    // duplicate (`x || x` where x is `a == 1 && b == 2`), so this fires — and
    // should. It is called out explicitly because it looks superficially like
    // the mixed-operator negative case above; the difference is that there the
    // two groups merely SHARE a fragment, while here they are textually
    // identical. Pinned so a future "don't cross operators" narrowing does not
    // silently drop a real defect.
    test('fires on two textually identical && groups joined by ||', () async {
      expect(await _fires('a == 1 && b == 2 || a == 1 && b == 2'), isTrue);
    });

    // KNOWN TRADEOFF (documented in the rule's class DartDoc): operands are
    // compared by `toSource()` text with NO purity analysis, so a deliberately
    // repeated impure call is flagged. `it.moveNext() && it.moveNext()` is the
    // real skip-every-other-element idiom and is a true positive only in the
    // sense that the rule cannot tell it apart from a copy-paste bug. This
    // test pins the behavior so the tradeoff is visible and any future purity
    // guard is a conscious, test-breaking decision rather than a silent drift.
    test('fires on a repeated impure call (documented tradeoff)', () async {
      final Set<String> codes = await reportedRuleCodes(
        DuplicateValueRule(),
        '''
bool skipAlternate(Iterator<int> it) {
  return it.moveNext() && it.moveNext();
}
''',
      );
      expect(
        codes.contains('duplicate_value'),
        isTrue,
        reason:
            'The rule has no purity guard by design; repeated impure calls are '
            'flagged and the user is expected to suppress with `// ignore:`.',
      );
    });
  });

  group('DuplicateValueRule - Fixture Verification', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/control_flow/duplicate_value_fixture.dart',
      );

      expect(file.existsSync(), isTrue);
    });
  });
}
