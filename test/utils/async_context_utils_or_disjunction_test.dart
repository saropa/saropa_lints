import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/async_context_utils.dart';
import 'package:test/test.dart';

/// Behavioral checks for `checksNotMounted` recursion through `||`
/// disjunctions and the corresponding `isNegatedMountedGuard` recognition.
///
/// Reproduces the false positive documented in
/// `plans/history/2026.05/2026.05.19/use_setstate_synchronously_false_positive_or_disjunction_mounted_guard.md`:
/// `if (cond || !mounted) return;` was not recognized as an early-exit
/// mounted guard, so subsequent `setState(...)` calls were flagged even
/// though the fall-through path proves `mounted == true`.
///
/// Asymmetry under test:
/// - `checksMounted` recurses into `&&` (positive: both operands must hold
///   for the then-branch — any operand asserting `mounted` is sufficient).
/// - `checksNotMounted` recurses into `||` (negative early-exit: the
///   fall-through proves !X, so when X = X1 || X2 and either operand is a
///   not-mounted check, the fall-through proves mounted is true).
/// - The dual does NOT hold in the opposite direction. `checksMounted`
///   must NOT recurse into `||`, and `checksNotMounted` must NOT recurse
///   into `&&` — those would over-accept unsafe guards.
void main() {
  group('checksNotMounted — || disjunction recursion', () {
    test('`!mounted || cond` (negated mounted on LHS)', () {
      final expr = _parseIfCondition('if (!mounted || value.isEmpty) return;');
      expect(checksNotMounted(expr), isTrue);
    });

    test('`cond || !mounted` (negated mounted on RHS — the consumer case)', () {
      final expr = _parseIfCondition('if (value.isEmpty || !mounted) return;');
      expect(checksNotMounted(expr), isTrue);
    });

    test('`cond1 || cond2 || !mounted` (3-deep recursion)', () {
      final expr = _parseIfCondition(
        'if (aborted || value.isEmpty || !mounted) return;',
      );
      expect(checksNotMounted(expr), isTrue);
    });

    test('`mounted == false || cond` (== false on LHS of ||)', () {
      final expr = _parseIfCondition(
        'if (mounted == false || value.isEmpty) return;',
      );
      expect(checksNotMounted(expr), isTrue);
    });

    test('`cond || !context.mounted` (PrefixedIdentifier inside ||)', () {
      final expr = _parseIfCondition(
        'if (value.isEmpty || !context.mounted) return;',
      );
      expect(checksNotMounted(expr), isTrue);
    });

    test('`cond1 || cond2` with no mounted operand — not a guard', () {
      final expr = _parseIfCondition(
        'if (aborted || value.isEmpty) return;',
      );
      // Sanity check: the new || branch must not accept arbitrary ||s.
      expect(checksNotMounted(expr), isFalse);
    });

    test('asymmetry: `mounted || cond` is NOT a positive guard', () {
      // `if (mounted || cond) { ... }` enters the then-branch when cond is
      // true regardless of mounted, so it must NOT be accepted as a
      // positive mounted guard. Guards `checksMounted` against an
      // over-eager symmetric fix.
      final expr = _parseIfCondition('if (mounted || force) doThing();');
      expect(checksMounted(expr), isFalse);
    });

    test('asymmetry: `cond || mounted` is NOT a positive guard', () {
      final expr = _parseIfCondition('if (force || mounted) doThing();');
      expect(checksMounted(expr), isFalse);
    });

    test('asymmetry: `!mounted && cond` is NOT a negated early-exit guard', () {
      // The negated early-exit guard recognizer's dual is `||`, not `&&`.
      // `if (!mounted && cond) return;` only exits when BOTH operands are
      // true — the fall-through does NOT prove mounted (cond could be
      // false while mounted is also false). Guards against an over-eager
      // symmetric fix.
      final expr = _parseIfCondition('if (!mounted && force) return;');
      expect(checksNotMounted(expr), isFalse);
    });
  });

  group('isNegatedMountedGuard — || disjunction recognition', () {
    test('`if (cond || !mounted) return;` is recognized', () {
      final stmt = _parseIfStatement('if (value.isEmpty || !mounted) return;');
      expect(isNegatedMountedGuard(stmt), isTrue);
    });

    test('`if (!mounted || cond) return;` is recognized', () {
      final stmt = _parseIfStatement('if (!mounted || value.isEmpty) return;');
      expect(isNegatedMountedGuard(stmt), isTrue);
    });

    test('`if (cond || !mounted) throw ...;` is recognized (throw exit)', () {
      final stmt = _parseIfStatement(
        "if (value.isEmpty || !mounted) throw StateError('disposed');",
      );
      expect(isNegatedMountedGuard(stmt), isTrue);
    });

    test('`if (cond || cond2) return;` without mounted — not a guard', () {
      final stmt = _parseIfStatement('if (a || b) return;');
      expect(isNegatedMountedGuard(stmt), isFalse);
    });

    test('`if (cond || !mounted) {}` without early exit — not a guard', () {
      // Even with the || recursion, an empty then-block lacks the
      // return/throw needed to make this an early-exit guard.
      final stmt = _parseIfStatement('if (value.isEmpty || !mounted) {}');
      expect(isNegatedMountedGuard(stmt), isFalse);
    });
  });
}

/// Parses [source] as the body of a synthetic function and returns the
/// condition expression of the first IfStatement it finds.
Expression _parseIfCondition(String ifSource) =>
    _parseIfStatement(ifSource).expression;

/// Parses [source] as the body of a synthetic function and returns the
/// first IfStatement it finds.
IfStatement _parseIfStatement(String ifSource) {
  final unit = parseString(
    content: '''
void f() async {
  $ifSource
}
''',
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  ).unit;

  IfStatement? found;
  unit.accept(_PickIf((node) => found ??= node));
  if (found == null) {
    throw StateError('No IfStatement parsed from: $ifSource');
  }
  return found!;
}

/// Picks the first `IfStatement` it sees.
class _PickIf extends RecursiveAstVisitor<void> {
  _PickIf(this.onPick);
  final void Function(IfStatement) onPick;

  @override
  void visitIfStatement(IfStatement node) {
    onPick(node);
    super.visitIfStatement(node);
  }
}
