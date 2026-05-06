# BUG: `avoid_missing_interpolation` / `prefer_interpolation_to_compose` — Raw-String Regex Concatenation Wrongly Flagged

**Status: Fixed**

Created: 2026-04-29
Rules: `avoid_missing_interpolation`, `prefer_interpolation_to_compose`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~3329)
Severity: False positive
Rule version: ? | Since: ? | Updated: ?

---

## Summary

`avoid_missing_interpolation` (and the related `prefer_interpolation_to_compose`) fire on `r'\s*' + RegExp.escape(...)` — the idiomatic Dart pattern for composing a regular expression from a raw-string literal pattern and a computed escaped fragment. Converting to interpolation forces dropping the raw-string benefit and writing `'\\s*${RegExp.escape(...)}'`, which is uglier, more error-prone (every `\` must be doubled), and harder to read for anyone who knows regex. Raw-string literals exist precisely so backslash-heavy patterns do not need double-escaping; flagging concatenation involving them defeats that purpose.

---

## Attribution Evidence

```bash
# Positive
grep -rn "'avoid_missing_interpolation'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_avoid_rules.dart:3345:    'avoid_missing_interpolation',
grep -rn "'prefer_interpolation_to_compose'" lib/src/rules/
# (defined nearby in same / sibling file)

# Negative
grep -rn "'avoid_missing_interpolation'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:3345`
**Rule class:** `AvoidMissingInterpolationRule`
**Diagnostic `source` / `owner`:** `dart`

---

## Reproducer

Real source: `d:/src/contacts/lib/service/bluesky_api/bluesky_post_item_extensions.dart` lines 138 and 165.

```dart
String _stripHashtags(String text, List<String> hashtags) {
  String result = text;
  for (final String tag in hashtags) {
    final String normalized = tag.startsWith('#') ? tag : '#$tag';
    // The literal `r'\s*'` is a RAW string regex pattern. Combining it with
    // a computed escaped fragment via + is the idiomatic way to compose a
    // regex without double-escaping every backslash.
    // LINT — but should NOT lint (FP)
    result = result.replaceAll(RegExp(r'\s*' + RegExp.escape(normalized)), '');
  }
  return result;
}

String _stripDomain(String text, String? embedDomain) {
  if (embedDomain == null) return text;
  // LINT — same FP
  final RegExp re = RegExp(r'https?:\/\/[^\s]*' + RegExp.escape(embedDomain));
  return text.replaceAll(re, '');
}
```

**Frequency:** Always — fires whenever a raw-string literal is `+`-concatenated with a non-literal string.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the string-literal operand is a **raw** string (`r'...'`). Raw strings exist to preserve backslashes; forcing interpolation defeats that purpose. |
| **Actual** | `[avoid_missing_interpolation] String concatenation using the + operator combines a string literal with a variable...` reported on each `r'...' + computed` site. The accompanying `[prefer_interpolation_to_compose]` (Dart core lint, not saropa_lints) also fires on the same span. |

---

## AST Context

```
ExpressionStatement
  └─ MethodInvocation (replaceAll)
      └─ argumentList
          └─ InstanceCreationExpression (RegExp)
              └─ argumentList
                  └─ BinaryExpression (+)        ← rule visits via addBinaryExpression
                      ├─ leftOperand: SimpleStringLiteral (isRaw == true, value: r'\s*')
                      └─ rightOperand: MethodInvocation (RegExp.escape(...))
```

The key fact the rule ignores: `(node.leftOperand as SimpleStringLiteral).isRaw` is `true`.

---

## Root Cause

`AvoidMissingInterpolationRule.runWithReporter` (lines 3357–3386):

```dart
context.addBinaryExpression((BinaryExpression node) {
  if (node.operator.type != TokenType.PLUS) return;
  // ...
  final bool leftIsLiteral = node.leftOperand is StringLiteral;
  final bool rightIsLiteral = node.rightOperand is StringLiteral;
  if (!leftIsLiteral && !rightIsLiteral) return;
  // ...
  reporter.atNode(node);
});
```

The rule checks `is StringLiteral` but never inspects `SimpleStringLiteral.isRaw`. A raw-string literal IS a `StringLiteral`, so it falls through to the report.

The rule should treat raw-string literals as un-convertible (interpolation expansion does not occur in raw strings; converting would change the string's character content unless every escape is manually doubled).

---

## Suggested Fix

In `lib/src/rules/code_quality/code_quality_avoid_rules.dart`, inside `AvoidMissingInterpolationRule.runWithReporter`, after the existing literal checks:

```dart
// Raw-string literals (r'...') deliberately disable escape processing to
// keep regex/backslash patterns readable. Converting r'\s*' + escaped to
// interpolation requires dropping the r-prefix and double-escaping every
// backslash, which is uglier and more error-prone. Skip raw-literal
// concatenations.
bool isRawLiteral(Expression e) =>
    e is SimpleStringLiteral && e.isRaw;
if (isRawLiteral(node.leftOperand) || isRawLiteral(node.rightOperand)) {
  return;
}
```

The same exemption should be applied to `prefer_interpolation_to_compose` if that rule is also defined in saropa_lints (the diagnostic in the user's Problems panel pairs both at the same span). If that name belongs to the Dart core analyzer, file separately at dart-lang/sdk.

---

## Fixture Gap

`example*/lib/code_quality/avoid_missing_interpolation_fixture.dart` should include:

1. `'foo' + bar` — expect LINT (regression)
2. `'foo $bar baz'` already interpolated — expect NO lint (regression)
3. `r'\s*' + RegExp.escape(x)` — expect NO lint (NEW)
4. `r'^\d+\$' + suffix` — expect NO lint (NEW)
5. `someString + r'\s*'` — expect NO lint (NEW; raw on the right)
6. `'foo' + r'bar'` — both literals, document expected behavior
7. `'foo' + 'bar'` (already-existing dart core `unnecessary_string_concatenations` territory) — document

---

## Changes Made

- Added [`expressionContainsRawStringLiteral`](../../lib/src/literal_context_utils.dart) and used it in `AvoidMissingInterpolationRule` and `PreferInterpolationToComposeRule` to skip diagnostics when either operand is or contains a raw `SimpleStringLiteral`.
- Extended [`example/lib/code_quality/avoid_missing_interpolation_fixture.dart`](../../example/lib/code_quality/avoid_missing_interpolation_fixture.dart) and [`example/lib/stylistic/prefer_interpolation_to_compose_fixture.dart`](../../example/lib/stylistic/prefer_interpolation_to_compose_fixture.dart) with raw-string `+` cases.

---

## Tests Added

- Fixture coverage only (existing fixture-driven rule tests in `test/code_quality_rules_test.dart` and `test/stylistic_rules_test.dart`).

---

## Commits

<!-- Fill in when fix lands. -->

---

## Environment

- saropa_lints version: 12.8.4
- Dart SDK version: Flutter 3.x channel
- custom_lint version: native analyzer plugin (no custom_lint)
- Triggering project/file: `d:/src/contacts/lib/service/bluesky_api/bluesky_post_item_extensions.dart` (lines 138, 165)

---

## Note on `prefer_interpolation_to_compose`

The Problems panel reports `prefer_interpolation_to_compose` at the same line/column with code `prefer_interpolation_to_compose`. If positive grep shows that rule is also defined in `saropa_lints`, fold the same raw-string exemption into both rules in this fix. If it is the Dart core analyzer's lint of the same name, the saropa_lints fix only suppresses the saropa_lints rule and the core lint still needs ignoring downstream — file separately at dart-lang/sdk if appropriate.
