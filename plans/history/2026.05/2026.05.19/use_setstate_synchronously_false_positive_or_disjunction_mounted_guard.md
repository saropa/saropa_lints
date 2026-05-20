# BUG: `use_setstate_synchronously` — false positive when negated mounted guard is on the RHS of an `||` disjunction (`if (cond || !mounted) return;`)

**Status: Fixed**

Created: 2026-05-19
Rule: `use_setstate_synchronously`
File: `lib/src/rules/widget/widget_lifecycle_rules.dart` (line ~2086, code at 2105–2167) + shared helper at `lib/src/async_context_utils.dart` (line ~87, helper `isNegatedMountedGuard` / `checksNotMounted`)
Severity: False positive (guard recognizer is asymmetric with the positive helper — see Root Cause)
Rule version: v10 | Since: v10 (introduced when `_OrderedSetStateScanner` was added) | Updated: v10

---

## Summary

The `_OrderedSetStateScanner` recognizes `if (!mounted) return;` as a Block-level early-exit guard, but only when the IfStatement's condition is structurally a single negated mounted check. A compound guard whose mounted check is one operand of an `||` disjunction — e.g. `if (holiday == null || !mounted) return;` — is NOT recognized, so a subsequent `setState(...)` in the same Block is flagged even though the code path to that `setState` already implies `mounted == true`.

The positive helper `checksMounted` already handles compound `&&` chains (it recursively checks both operands of `AMPERSAND_AMPERSAND`). The negative helper `checksNotMounted` has no matching `||` (`BAR_BAR`) branch. The asymmetry is the bug: in boolean terms, `if (A && mounted) { use_mounted; }` and `if (A || !mounted) return; use_mounted;` are duals, but the rule only recognizes the former.

---

## Attribution Evidence

```bash
# Positive — rule IS defined in saropa_lints
$ grep -rn "'use_setstate_synchronously'" lib/src/rules/
lib/src/rules/widget/widget_lifecycle_rules.dart:2106:    'use_setstate_synchronously',
```

```bash
# Negative — rule is NOT defined in saropa_drift_advisor (source label "dart" is misleading
# in the consumer's Problems panel; same label both repos use)
$ grep -rn "'use_setstate_synchronously'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# (zero matches)
```

**Emitter registration:** `lib/src/rules/widget/widget_lifecycle_rules.dart:2086` (`UseSetStateSynchronouslyRule`)
**Rule class:** `UseSetStateSynchronouslyRule` — registered in `lib/src/rules/all_rules.dart`
**Helper class under suspicion:** `_OrderedSetStateScanner` (same file, lines 2169–2244) + `isNegatedMountedGuard` / `checksNotMounted` in `lib/src/async_context_utils.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (the saropa_lints native analyzer plugin emits under the `dart` source — the rule message text `[use_setstate_synchronously] ... {v10}` is the saropa_lints fingerprint)

---

## Reproducer

Consumer project: `D:\src\contacts`. Site: `lib/components/home/section/home_section_in_focus.dart:262` (rule version v10 in effect as of 2026-05-19).

Minimal shape (strip away the consumer's I/O and types — only the control flow matters):

```dart
class _ExampleState extends State<Example> {
  String? _result;

  Future<void> _load() async {
    try {
      final List<int>? items = await _fetch();
      if (!mounted || items == null) return;  // OK — rule already accepts !mounted on LHS of ||

      String? picked;
      for (final int item in items) {
        if (item > 0) {
          picked = item.toString();
          break;
        }
      }

      // The compound guard below short-circuits to `return` when EITHER
      // `picked == null` OR `!mounted` is true. The fall-through path
      // therefore implies `mounted == true`. This setState is safe.
      if (picked == null || !mounted) return;  // ← negated mounted on RHS of ||

      // expect_lint: NONE — but rule v10 reports use_setstate_synchronously here.
      setState(() => _result = picked);
    } on Object catch (_) {}
  }

  Future<List<int>?> _fetch() async => <int>[1, 2, 3];
}
```

**Frequency:** Always — any `setState` call following an `if (cond || !mounted) return;` at top-level of a Block lexically after an `await`.

Note the symmetry test: swap the operands so the negated mounted check is on the LHS (`if (!mounted || picked == null) return;`) and the diagnostic disappears, even though the runtime control flow is identical — the LHS short-circuits identically once `!mounted` is true. The rule's recognition is purely structural, not semantic.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The compound guard `cond || !mounted` returns when `!mounted` is true, so the fall-through path implies `mounted == true`. Same boolean dual as the rule's existing accept-list for `if (mounted && cond) setState(...)`. |
| **Actual** | `[use_setstate_synchronously] setState called after async gap without mounted check. ... {v10}` reported at the `setState(...)` line. |

---

## AST Context

The flagged `setState` and its guarding `IfStatement` siblings inside the enclosing Block:

```
MethodDeclaration (_load, async)
  └─ BlockFunctionBody
      └─ Block
          └─ TryStatement
              └─ Block (try body)
                  ├─ VariableDeclarationStatement (items, has AwaitExpression)
                  ├─ IfStatement  ← cond: BinaryExpression(!, mounted, ||, ==, items, null)
                  │      thenStatement: ReturnStatement
                  ├─ VariableDeclarationStatement (picked)
                  ├─ ForStatement (...)
                  ├─ IfStatement  ← cond: BinaryExpression(==, picked, null, ||, !, mounted)
                  │      thenStatement: ReturnStatement
                  │      ↑ rule's `isNegatedMountedGuard` returns FALSE here
                  │        because `checksNotMounted` does not descend into `||`
                  └─ ExpressionStatement
                      └─ MethodInvocation (setState)  ← reported (`_isGuarded == false`)
```

The first `IfStatement` (`!mounted || items == null`) IS recognized by the rule today (because `!` is the OUTERMOST operator — `checksNotMounted` matches the `PrefixExpression(BANG, mounted)` form via `expr.operand`; the `||` chain is never inspected because the rule sees a `BANG` at the top level on the LHS path).

Wait — re-reading `checksNotMounted` more carefully: it only matches `PrefixExpression(BANG, mounted)` or `mounted == false`. A `BinaryExpression(||, ..., ...)` does not match either branch. So **both** compound forms (`!mounted || X` and `X || !mounted`) should fail to be recognized.

If the LHS form `if (!mounted || items == null) return;` is actually accepted in the consumer codebase, that would mean `checksNotMounted` is being called recursively somewhere I haven't traced — or, more likely, a separate path inside `containsEarlyExit` / `isNegatedMountedGuard` short-circuits on the AST shape. Worth tracing during investigation; either way the consumer reproducer at `home_section_in_focus.dart:243` (`if (!mounted || items == null) return;`) does NOT lint, but the one at line 260 (`if (holiday == null || !mounted) return;`) does. That gives the investigator a concrete A/B pair in the same function to bisect against.

---

## Root Cause

### Hypothesis A (primary): `checksNotMounted` does not handle `||` disjunction

`lib/src/async_context_utils.dart:63-78`:

```dart
bool checksNotMounted(Expression expr) {
  if (expr is PrefixExpression && expr.operator.type == TokenType.BANG) {
    return checksMounted(expr.operand);
  }
  if (expr is BinaryExpression && expr.operator.type == TokenType.EQ_EQ) {
    final left = expr.leftOperand;
    final right = expr.rightOperand;
    if (_isFalseLiteral(left) && checksMounted(right)) return true;
    if (_isFalseLiteral(right) && checksMounted(left)) return true;
  }
  return false;
}
```

No branch for `expr is BinaryExpression && expr.operator.type == TokenType.BAR_BAR`. The sibling `checksMounted` at lines 52-55 has the `&&` equivalent:

```dart
if (expr is BinaryExpression &&
    expr.operator.type == TokenType.AMPERSAND_AMPERSAND) {
  return checksMounted(expr.leftOperand) || checksMounted(expr.rightOperand);
}
```

For the early-exit `if (cond) return;` form, the dual is: if EITHER operand of `||` is a not-mounted check, the fall-through path implies `mounted == true`. Same recursive shape, opposite operator.

### Hypothesis B (secondary, less likely): `isNegatedMountedGuard` rejects the IfStatement at a higher level

`lib/src/async_context_utils.dart:87-95`:

```dart
bool isNegatedMountedGuard(Statement stmt) {
  if (stmt is! IfStatement) return false;
  if (!checksNotMounted(stmt.expression)) return false;
  return containsEarlyExit(stmt.thenStatement);
}
```

Both checks call into `checksNotMounted`, so Hypothesis A subsumes this — fixing `checksNotMounted` fixes `isNegatedMountedGuard` automatically. No separate work needed here.

---

## Suggested Fix

Extend `checksNotMounted` (`lib/src/async_context_utils.dart`) to recurse into `||` (`BAR_BAR`) the same way `checksMounted` recurses into `&&`:

```dart
bool checksNotMounted(Expression expr) {
  if (expr is PrefixExpression && expr.operator.type == TokenType.BANG) {
    return checksMounted(expr.operand);
  }
  if (expr is BinaryExpression && expr.operator.type == TokenType.EQ_EQ) {
    final left = expr.leftOperand;
    final right = expr.rightOperand;
    if (_isFalseLiteral(left) && checksMounted(right)) return true;
    if (_isFalseLiteral(right) && checksMounted(left)) return true;
  }

  // Compound `||` disjunction: `cond || !mounted` or `!mounted || cond`.
  // For an early-exit guard `if (X) return;`, the fall-through path
  // implies !X. If either operand of an || disjunction X1 || X2 is
  // a not-mounted check, then !X implies the corresponding operand is
  // false, i.e. mounted is true. So checking either operand is
  // sufficient. This is the dual of the && handling in checksMounted.
  if (expr is BinaryExpression &&
      expr.operator.type == TokenType.BAR_BAR) {
    return checksNotMounted(expr.leftOperand) ||
        checksNotMounted(expr.rightOperand);
  }

  return false;
}
```

Important: do NOT add `||` to `checksMounted`. The dual does not hold for the positive guard — `if (mounted || cond) { use_mounted; }` enters the then-branch when `cond` is true regardless of `mounted`, so it is NOT a safe positive guard. The asymmetry is on purpose; `checksMounted` only narrows when ALL paths through the condition assert mounted (hence `&&`), and `checksNotMounted` only narrows the fall-through when ANY path of the negated condition is `!mounted` (hence `||`).

---

## Fixture Gap

The fixture at `example/lib/async/use_setstate_synchronously_fixture.dart` covers:

1. `if (mounted) { setState(...); }` — accepted (positive single guard)
2. `if (!mounted) return; setState(...);` — accepted (negated single guard, return)
3. `if (!mounted) throw ...; setState(...);` — accepted (negated single guard, throw)
4. setState inside try-with-later-await but lexically before await — accepted (from the 2026-04-26 fix)

Missing:

1. **`if (!mounted || cond) return; setState(...);`** — `!mounted` on LHS of `||` — expect NO lint
2. **`if (cond || !mounted) return; setState(...);`** — `!mounted` on RHS of `||` — expect NO lint **(THE CONSUMER CASE — line 260 in home_section_in_focus.dart)**
3. **`if (cond1 || cond2 || !mounted) return; setState(...);`** — `!mounted` nested deeper in a multi-operand `||` chain — expect NO lint (catches recursion correctness)
4. **`if (mounted || cond) { setState(...); }`** — `mounted` on LHS of `||` — expect LINT (negative test; this is NOT a safe positive guard, so the rule MUST still fire)
5. **`if (cond || mounted) { setState(...); }`** — `mounted` on RHS of `||` — expect LINT (negative test, same reasoning as #4)

Cases 4 and 5 protect against an over-eager fix that adds `||` to BOTH helpers.

---

## Changes Made

- `lib/src/async_context_utils.dart` — `checksNotMounted` now recurses into `BinaryExpression` whose operator is `BAR_BAR` (`||`). If EITHER operand is itself a not-mounted check, the expression as a whole counts as a not-mounted check, so `if (cond || !mounted) return;` (and the LHS form, and N-deep chains) are recognized as early-exit guards. The dual is intentionally NOT mirrored in `checksMounted` for `||`: `if (mounted || cond) { ... }` enters the then-branch when `cond` alone is true and is therefore not a safe positive guard.
- `lib/src/rules/widget/widget_lifecycle_rules.dart` — diagnostic message version marker bumped `{v10}` → `{v11}` so consumers can tell the new behavior from the old one in the Problems panel.
- `analysis_options.yaml` — bumped the cached `use_setstate_synchronously` comment from `{v9}` to `{v11}` to track the source-of-truth rule version.

The fix also flows through to `isNegatedMountedGuard` (calls `checksNotMounted`) and `context_rules.dart:321` (uses `isNegatedMountedGuard`), so `avoid_context_across_async` and any sibling rule that recognizes negated mounted guards picks up the same `||` handling for free.

---

## Tests Added

- `test/utils/async_context_utils_or_disjunction_test.dart` — 14 unit tests covering:
  - `checksNotMounted` accepts `!mounted` on LHS / RHS of `||`, accepts a 3-deep chain, accepts `mounted == false || cond`, accepts `cond || !context.mounted`, and rejects `||` with no mounted operand.
  - Asymmetry guards: `checksMounted` rejects `mounted || cond` and `cond || mounted`; `checksNotMounted` rejects `!mounted && cond`.
  - `isNegatedMountedGuard` accepts the new `||` shapes with `return` and `throw`, and rejects `||` without a mounted operand or without an early exit.
- `example/lib/async/use_setstate_synchronously_fixture.dart` — five end-to-end fixture cases:
  1. `GoodNotMountedLhsOfOrGuard` — `if (!mounted || cond) return;` → no lint.
  2. `GoodNotMountedRhsOfOrGuard` — `if (cond || !mounted) return;` → no lint (the consumer reproducer).
  3. `GoodNotMountedDeepInOrChain` — `if (cond1 || cond2 || !mounted) return;` → no lint.
  4. `BadMountedLhsOfOr` — `if (mounted || cond) setState(...);` → still lints (`expect_lint: use_setstate_synchronously`).
  5. `BadMountedRhsOfOr` — `if (cond || mounted) setState(...);` → still lints.

Cases 4 and 5 are the negative tests that protect against a future regression where someone mirrors the `||` branch into `checksMounted`.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: v10 of `use_setstate_synchronously` (matches the `{v10}` marker in the diagnostic message)
- Dart SDK version: (consumer project's pinned Flutter 3.44 toolchain)
- custom_lint version: N/A — saropa_lints is a native `analysis_server_plugin`, not a custom_lint plugin. Diagnostic reaches the IDE Problems panel via the native plugin under `source: dart` (this is the saropa_lints fingerprint, not the stock Dart linter — the message format with `[rule_name] ... Quick fix available: ... {v10}` is unique to saropa_lints).
- Triggering project/file: `D:\src\contacts\lib\components\home\section\home_section_in_focus.dart:262` (consumer codebase, rule fires inside `_InFocusCardScrollerState._loadTodaysPublicHoliday`)

---

## Consumer Workaround

In the consumer code, the immediate workaround is to use the project's `SafeSetStateMixin` (`lib/utils/mixins/safe_set_state_mixin.dart`) which exposes `setStateSafe(...)`. The rule only matches `node.methodName.name == 'setState'` exactly (lib/src/rules/widget/widget_lifecycle_rules.dart:2231), so calls to `setStateSafe(...)` sidestep the diagnostic entirely AND the mounted check is centralized in the helper. That is preferable to scattering `// ignore: use_setstate_synchronously` markers across the codebase, and it removes the need for the consumer to know about this false positive at all.

This workaround does NOT close the bug — the rule still misses the `||` disjunction case wherever a project uses raw `setState` after a compound mounted guard.
