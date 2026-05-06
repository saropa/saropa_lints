# BUG: `no_runtimetype_tostring` — Debug Formatter / `toString()` Override Wrongly Flagged

**Status: Fixed**

Created: 2026-04-29
Rule: `no_runtimetype_tostring`
File: `lib/src/rules/stylistic/stylistic_rules.dart` (line ~4828)
Severity: False positive
Rule version: ? | Since: ? | Updated: ?

---

## Summary

The rule flags `obj.runtimeType.toString()` and tells the user to "use `is` checks or compare runtimeType directly". This advice is correct for control-flow type discrimination but wrong for **diagnostic formatters** — code inside a `toString()` override, a debug helper, or a logging path whose entire purpose is to produce a human-readable type name string. There is no `is` substitute for "render the runtime type as text"; that is the literal output the call exists to produce.

---

## Attribution Evidence

```bash
# Positive
grep -rn "'no_runtimetype_tostring'" lib/src/rules/
# lib/src/rules/stylistic/stylistic_rules.dart:4850:    'no_runtimetype_tostring',

# Negative
grep -rn "'no_runtimetype_tostring'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/stylistic/stylistic_rules.dart:4850`
**Rule class:** `NoRuntimeTypeToStringRule`
**Diagnostic `source` / `owner`:** `dart`

---

## Reproducer

Real source: `d:/src/contacts/lib/models/search/search_term_result.dart` line 41.

```dart
class SearchTermResult {
  final dynamic resultMatch;
  String? get __debugString {
    String properties = '';
    if (resultMatch != null) {
      // This is a DEBUG FORMATTER — its job is to produce a human-readable
      // label for whatever runtime type is found. There is no `is` check
      // that can substitute for "render the type name as a string".
      final String typeValue = resultMatch is String
          ? resultMatch.toString()
          : resultMatch.runtimeType.toString();  // LINT — but should NOT lint (FP)
      properties += ' found: $typeValue';
    }
    return properties;
  }

  @override
  String toString() => __debugString ?? super.toString();
}
```

**Frequency:** Always — fires on every `runtimeType.toString()` site regardless of enclosing context.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the call appears inside a `toString()` override, a debug-only getter (e.g., named `__debugString`, `_debug…`), a method passed to `debugPrint`/`debug`/`debugException` logging helpers, or a `Diagnosticable.toStringShort()` chain. The whole purpose is to produce text. |
| **Actual** | `[no_runtimetype_tostring] Avoid calling toString() on runtimeType.` reported on every site. |

---

## AST Context

```
ClassDeclaration (SearchTermResult)
  └─ MethodDeclaration (get __debugString) OR MethodDeclaration (toString)  ← rule should consult enclosing
      └─ ...
          └─ MethodInvocation (toString)        ← rule visits via addMethodInvocation (presumably)
              └─ realTarget: PropertyAccess (.runtimeType)
                  └─ realTarget: SimpleIdentifier (resultMatch)
```

---

## Root Cause

The rule (per its short docstring) reports any `obj.runtimeType.toString()` invocation without checking the enclosing method/getter. Inside `toString()` and debug formatters, the string output **is** the deliverable, and the suggested replacement (`is` checks) cannot satisfy the contract.

### Hypothesis A — Skip when enclosing declaration is `toString` / debug formatter

Walk `node.thisOrAncestorOfType<MethodDeclaration>()`:
- If the enclosing method's name is `toString`, exempt.
- If the enclosing method's name starts with `debug`, `_debug`, or `__debug`, exempt.
- If the enclosing method is annotated `@override` and overrides `Diagnosticable.toStringShort` / `Object.toString`, exempt.

### Hypothesis B — Skip when the result is concatenated into a debug log call

Harder; would require tracking the data flow from the call to a `debugPrint`/`print`/string-format target. Hypothesis A is sufficient and cheap.

---

## Suggested Fix

In `lib/src/rules/stylistic/stylistic_rules.dart` near `NoRuntimeTypeToStringRule.runWithReporter`:

```dart
// Skip if the enclosing method is toString() or a debug formatter — the
// whole point there is to render a human-readable type label. There is no
// `is` substitute for "produce a text representation of a runtime type".
final MethodDeclaration? enclosingMethod = node.thisOrAncestorOfType<MethodDeclaration>();
if (enclosingMethod != null) {
  final String methodName = enclosingMethod.name.lexeme;
  if (methodName == 'toString' ||
      methodName.startsWith('debug') ||
      methodName.startsWith('_debug') ||
      methodName.startsWith('__debug')) {
    return;
  }
}
```

Also exempt `Diagnosticable.toStringShort` overrides and getter-form debug formatters (the rule should also walk to the enclosing `MethodDeclaration` for getters). Bump rule version. Update docstring with a "Not flagged" section.

---

## Fixture Gap

`example*/lib/stylistic/no_runtimetype_tostring_fixture.dart` should include:

1. `obj.runtimeType.toString()` in arbitrary code — expect LINT (regression)
2. `obj.runtimeType.toString()` inside `String toString() => ...` — expect NO lint (NEW)
3. `obj.runtimeType.toString()` inside `String? get __debugString` getter — expect NO lint (NEW)
4. `obj.runtimeType.toString()` inside `String debugLabel() => ...` — expect NO lint (NEW)
5. `obj.runtimeType.toString()` inside `Diagnosticable.toStringShort` override — expect NO lint (NEW)

---

## Changes Made

- `NoRuntimeTypeToStringRule`: skip reporting when the invocation appears under an enclosing `MethodDeclaration` or `FunctionDeclaration` whose name is `toString`, `toStringShort`, or starts with `debug`, `__debug`, or `_debug`. Walks the full ancestor chain so nested local functions inside `toString()` / `__debugString` remain exempt.
- Doc: **Not flagged** section, rule version **v2**.
- Fixture: corrected `expect_lint` rule id to `no_runtimetype_tostring`; added GOOD cases for `toString`, `__debugString`, `debug`-prefixed top-level function, `toStringShort`, and nested local inside `toString`.

---

## Tests Added

- `test/stylistic_rules_test.dart`: `no_runtimetype_tostring` group — one `expect_lint` in fixture; fixture contains exempt patterns (`toString`, `__debugString`, `toStringShort`).

---

## Commits

<!-- Fill in when merged. -->

---

## Environment

- saropa_lints version: 12.8.4
- Dart SDK version: Flutter 3.x channel
- custom_lint version: native analyzer plugin (no custom_lint)
- Triggering project/file: `d:/src/contacts/lib/models/search/search_term_result.dart` (line 41, inside `__debugString` getter that backs `toString()`)
