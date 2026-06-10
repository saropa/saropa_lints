# BUG: `avoid_string_substring` — Guard heuristics go inert when a substring argument is a property/index access (`x.length`, `match.start`, `m.i!`, `split[0]`)

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_string_substring`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~1176, `_collectIdentifierNames`)
Severity: False positive
Rule version: v3 | Since: (pre-v13) | Updated: v13.12.2

---

## Summary

`_collectIdentifierNames` (the helper that extracts identifier names from
`substring()` arguments so the guard heuristics can match them against an
enclosing condition) only descends into `SimpleIdentifier`,
`BinaryExpression`, `PrefixExpression`, and `ParenthesizedExpression`. It does
**not** handle `PrefixedIdentifier` / `PropertyAccess` (`shareSourcePrefix.length`,
`match.start`, `m.i!`), `IndexExpression` (`split[0]`), or `PostfixExpression`
(the `!` in `m.i!`). When a substring argument is one of these, the collected
arg-name set is **empty**, which silently disables *every* argument-based guard:
`_conditionInvolvesArgs`, `_forConditionInvolvesArgs`, and
`_hasPrecedingEarlyExitGuard` all short-circuit to `false` on an empty set. Code
that is provably in-bounds via a `startsWith` early-exit or an `indexOf`-derived
index then fires the lint.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_string_substring'" lib/src/rules/
# => lib/src/rules/code_quality/code_quality_avoid_rules.dart:991:    'avoid_string_substring',

# Negative — not a rule in the drift advisor (only a disabled-rule config line)
grep -rn "avoid_string_substring" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# => 0 matches in lib/src or extension/src
#    (only hit is ../saropa_drift_advisor/analysis_options.yaml:108 — a
#     `avoid_string_substring: false` config toggle, not a definition)
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:974` (`class AvoidSubstringRule`)
**Rule class:** `AvoidSubstringRule` — registered in `lib/saropa_lints.dart:326` (`AvoidSubstringRule.new`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
// Case 1 — startsWith early-exit + `.length` substring arg (PrefixedIdentifier).
String? extractSuffix(String? value, String prefix) {
  if (value == null || !value.startsWith(prefix)) return null;
  return value.substring(prefix.length); // LINT — but provably in-bounds
}

// Case 2 — RegExpMatch.start substring arg (PropertyAccess).
String headBeforeMarker(String text, RegExp marker) {
  final RegExpMatch? match = marker.firstMatch(text);
  if (match == null) return text;
  return text.substring(0, match.start); // LINT — match.start is always <= text.length
}

// Case 3 — `.length` arg inside a guarded while loop.
String? stripTrailingSlash(String url) {
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1); // LINT — url is non-empty here
  }
  return url;
}
```

**Frequency:** Always, whenever a substring argument is a `x.prop`, `x.prop!`, or `x[i]` expression.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — each call is bounds-guarded; the guard just happens to involve a property/index expression. |
| **Actual** | `[avoid_string_substring] substring() throws RangeError ...` reported at the `substring` call. |

---

## AST Context

```
MethodDeclaration (extractSuffix)
  └─ Block
      ├─ IfStatement  (value == null || !value.startsWith(prefix))  → return null
      └─ ReturnStatement
          └─ MethodInvocation  value.substring(prefix.length)   ← reported
                argumentList:
                  PrefixedIdentifier (prefix.length)  ← _collectIdentifierNames returns {} here
```

`_collectIdentifierNames(prefix.length, names)` falls through all four
`if`/`else if` branches (it is a `PrefixedIdentifier`, not a `SimpleIdentifier`)
and adds nothing. `argNames` is therefore empty, so
`_hasPrecedingEarlyExitGuard` returns at its first line
(`if (argNames.isEmpty) return false;`), missing the `!value.startsWith(prefix)`
early-exit entirely.

---

## Root Cause

### Mechanism

`_collectIdentifierNames` (lib/src/rules/code_quality/code_quality_avoid_rules.dart:1187–1198):

```dart
static void _collectIdentifierNames(Expression expr, Set<String> names) {
  if (expr is SimpleIdentifier) {
    names.add(expr.name);
  } else if (expr is BinaryExpression) {
    _collectIdentifierNames(expr.leftOperand, names);
    _collectIdentifierNames(expr.rightOperand, names);
  } else if (expr is PrefixExpression) {
    _collectIdentifierNames(expr.operand, names);
  } else if (expr is ParenthesizedExpression) {
    _collectIdentifierNames(expr.expression, names);
  }
  // No PropertyAccess / PrefixedIdentifier / IndexExpression / PostfixExpression
}
```

Real-world substring arguments are very often `x.length`, `match.start`,
`m.i!`, or `split[0]`. All four resolve to AST node types this function does
not visit, so their identifiers (`prefix`, `match`, `m`, `split`) are never
collected. Downstream, line 1112 (`if (argNames.isEmpty) return false;`) and
line 1144 (same in `_hasPrecedingEarlyExitGuard`) treat "no collectable arg
names" as "no guard possible", producing the false positive.

This single defect accounts for the bulk of the flagged sites in the
downstream project: `backup_blob_codec.dart:64` (`value.substring(base64Prefix.length)`),
`contact_sharing_utils.dart:63` (`shareSource.substring(shareSourcePrefix.length)`),
`contact_merged_view.dart:217` (`url.substring(0, url.length - 1)`),
`signature_block_splitter.dart:47` (`text.substring(0, match.start)`),
`zxcvbn_matching.dart:247` (`password.substring(m.i!, m.j! + 1)`),
`zxcvbn_matching.dart:493–495` (`token.substring(0, split[0])`, etc.).

---

## Suggested Fix

Extend `_collectIdentifierNames` to descend into the missing node types so the
guard heuristics see the controlling variable:

```dart
static void _collectIdentifierNames(Expression expr, Set<String> names) {
  if (expr is SimpleIdentifier) {
    names.add(expr.name);
  } else if (expr is BinaryExpression) {
    _collectIdentifierNames(expr.leftOperand, names);
    _collectIdentifierNames(expr.rightOperand, names);
  } else if (expr is PrefixExpression) {
    _collectIdentifierNames(expr.operand, names);
  } else if (expr is ParenthesizedExpression) {
    _collectIdentifierNames(expr.expression, names);
  } else if (expr is PostfixExpression) {
    // `m.i!` — unwrap the null-assertion to reach the target.
    _collectIdentifierNames(expr.operand, names);
  } else if (expr is PrefixedIdentifier) {
    // `prefix.length`, `match.start` — collect BOTH the prefix and the
    // property so a guard referencing either is recognized.
    names.add(expr.prefix.name);
    names.add(expr.identifier.name);
  } else if (expr is PropertyAccess) {
    // `m.i`, `obj.field.length`
    final Expression? target = expr.target;
    if (target != null) _collectIdentifierNames(target, names);
    names.add(expr.propertyName.name);
  } else if (expr is IndexExpression) {
    // `split[0]` — the receiver name (`split`) is what a guard would mention.
    _collectIdentifierNames(expr.realTarget, names);
  }
}
```

Note: collecting the property name (`length`, `start`) as well as the receiver
keeps `_conditionInvolvesArgs` matching for guards written as
`if (s.length > prefix.length)` where only the property word overlaps.

---

## Fixture Gap

The fixture at `example*/lib/code_quality/avoid_string_substring_fixture.dart`
should include:

1. `value.substring(prefix.length)` after `if (!value.startsWith(prefix)) return null;` — expect **NO** lint.
2. `text.substring(0, match.start)` after `if (match == null) return text;` — expect **NO** lint.
3. `url.substring(0, url.length - 1)` inside `while (url.endsWith('/'))` — expect **NO** lint.
4. `password.substring(m.i!, m.j! + 1)` where a preceding guard references `m.i`/`m.j` — expect **NO** lint.
5. Control case: `value.substring(prefix.length)` with NO preceding guard — expect **LINT** (must still fire).

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: >=3.9.0 <4.0.0 (per pubspec environment constraint)
- analyzer: >=9.0.0 <13.0.0
- Triggering project/file: `d:\src\contacts` — `lib/database/file_backup/backup_blob_codec.dart:64`, `lib/utils/contact/contact_sharing_utils.dart:63`, `lib/utils/contact/matching/contact_merged_view.dart:217`, `lib/utils/contact/signature/signature_block_splitter.dart:47`, `lib/utils/zxcvbn/src/zxcvbn_matching.dart:247`, `:493`, `:494`, `:495`

## Finish Report (2026-06-10)

Fixed in WS-1. `_collectIdentifierNames` now descends into `PostfixExpression` (`m.i!`), `PrefixedIdentifier` (`prefix.length` — collects both prefix and property), `PropertyAccess` (`match.start`), and `IndexExpression` (`split[0]`), so argument-based guards are no longer silently disabled by an empty arg-name set. Verified by the guard unit test (prefix.length arg after startsWith; match.start arg after null guard).
