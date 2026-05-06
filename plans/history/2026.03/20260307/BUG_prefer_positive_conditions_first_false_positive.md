# Bug: `prefer_positive_conditions_first` false positive on null-guard clauses

**Status:** Fixed (v3 — null-guard exclusion + message rewrite)
**Rule:** `prefer_positive_conditions_first` (v3)
**Severity:** False positive — flags valid code that should not trigger
**Plugin version:** saropa_lints v8.0.7 (professional tier)

## Problem

The rule flags **null-guard clauses** (`if (x == null) { return fallback; }`) as needing the positive condition first, even though this is a standard early-return guard pattern that keeps the happy path un-nested and prominent.

## Reproduction

**File:** `lib/app_router.dart`, line 228

```dart
pageBuilder: (context, state) {
  final args = SuperFabMenuArgsHolder.take();

  if (args == null) {
    return _buildAdaptivePage(
      context,
      state,
      _buildArgsFallback(
        context,
        AppLocalizations.of(context)?.superFabMenuMissingArgs ?? 'Missing arguments.',
      ),
    );
  }

  return _buildAdaptivePage(
    context,
    state,
    SuperFabFullScreenMenu(title: args.title, items: args.items),
  );
},
```

**Diagnostic output:**

```
[prefer_positive_conditions_first] Guard clauses with negated conditions push
the happy path deeper into the function. Positive conditions make the primary
logic path prominent and easier to understand. {v2}
Restructure to place the positive condition first so the happy path is
prominent and easier to follow.
```

## Why this is wrong

1. **This IS the positive-condition-first pattern.** The code checks `args == null` (the error case) and returns early, leaving the happy path (`args != null`) at the top indentation level. The rule's own description says "positive conditions make the primary logic path prominent" — which is exactly what this guard clause achieves.

2. **The suggested fix would make the code worse.** Inverting to `if (args != null) { return happy; } else { return fallback; }` or `if (args != null) { return happy; } return fallback;` would:
   - Nest the happy path (the longer, more important code) inside a conditional block
   - Violate the widely-accepted Dart style of using early returns for guard clauses
   - Contradict the `prefer_guard_clause` pattern recommended by most style guides

3. **`== null` is not a "negated condition".** The rule description mentions "negated conditions" but `== null` is an equality check, not a negation. A negated condition would be `if (!isValid)` or `if (!(x > 0))`. The rule appears to treat null checks as inherently negative, which is semantically incorrect — null-checking is a standard validation pattern.

4. **This pattern is idiomatic Dart.** The Dart style guide and `go_router` examples both use early-return null guards extensively. This file has multiple instances of the same pattern (lines 172, 205, 228) — all flagged, all correct.

## Expected behavior

The rule should NOT fire when:

- The condition is a null-equality check (`x == null`) followed by an early return
- The `if` block contains only a `return` statement (guard clause pattern)
- The code after the `if` block is the un-nested happy path

## Suggested fix

Detect and skip guard-clause patterns:

```dart
// Skip guard clauses: if (x == null) { return ...; }
if (condition is BinaryExpression &&
    condition.operator.type == TokenType.EQ_EQ &&
    (condition.rightOperand is NullLiteral || condition.leftOperand is NullLiteral) &&
    ifBody.statements.length == 1 &&
    ifBody.statements.first is ReturnStatement &&
    node.elseStatement == null) {
  return; // This is a valid guard clause
}
```

## Impact

This false positive is extremely noisy in apps using GoRouter, Provider, or any nullable-API pattern. Every null-guard clause generates a violation. In `app_router.dart` alone, 3 of the same pattern are flagged. Across a typical Flutter app with dozens of null guards, this inflates violation counts substantially and trains developers to ignore the rule entirely.
