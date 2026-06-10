# BUG: `avoid_manual_date_formatting` — False Positive on Non-DateTime Integer Fields and Internal Key Strings

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_manual_date_formatting`
File: `lib/src/rules/ui/internationalization_rules.dart` (line ~1569)
Severity: False positive
Rule version: v3 | Since: (see rule header) | Updated: v4.13.0

---

## Summary

`avoid_manual_date_formatting` fires on `StringInterpolation` nodes that
contain two or more accesses to properties named `day`, `month`, `year`, etc.
The rule's `_isDateTimeName` helper treats any target whose static type is
unavailable (`null`) as "potentially DateTime" to avoid false negatives. This
over-fires on two categories of correct code: (a) string interpolations that
build **internal non-user-facing keys** (dedup keys, stable IDs, hash inputs)
where locale formatting is inapplicable, and (b) interpolations of **plain
`int` fields** on project-specific types such as `DateTimeNullable` or
Hebrew-calendar structs whose static type name does not match `"DateTime"` but
whose `.month` / `.day` / `.year` getters trigger the property name check. Both
categories require an `// ignore: avoid_manual_date_formatting` workaround today.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive — rule IS defined here
grep -rn "'avoid_manual_date_formatting'" lib/src/rules/
# lib/src/rules/ui/internationalization_rules.dart:1569:     'avoid_manual_date_formatting',
```

The rule is registered at `lib/src/rules/ui/internationalization_rules.dart`
line 1569 as `AvoidManualDateFormattingRule`. Attribution is confirmed; the
diagnostic owner in the IDE Problems panel is
`_generated_diagnostic_collection_name_#N` (the analysis-server plugin host),
not a sibling repo, so negative attribution is not required.

**Emitter registration:** `lib/src/rules/ui/internationalization_rules.dart:1569`
**Rule class:** `AvoidManualDateFormattingRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#N`

---

## Reproducer

```dart
// Case A — internal dedup key, not user-facing copy.
// The variable is named 'dedupKey' but the rule only checks the name of the
// VariableDeclaration immediately wrapping the StringInterpolation. Here the
// interpolation is a nested expression (passed directly to a function), so the
// VariableDeclaration parent walk never fires.
String buildEventDedupKey(String label, CalendarEvent event) {
  return '$label|${event.month}|${event.day}'; // LINT — internal key, locale irrelevant
}

// Case B — plain int fields on a project-specific type.
// HebrewDate has .month and .day getters of type int; its static type name is
// 'HebrewDate', not 'DateTime' or 'DateTime?'. But because
// _isDateTimeName(null) returns true when type resolution fails (or the type
// name is an unknown custom class that the rule does NOT check for), the
// property names alone trigger the count threshold.
String hebrewLabel(HebrewDate hd) {
  return '${hd.month}/${hd.day}'; // LINT — HebrewDate is not DateTime; no locale API exists
}

// Case C — internal key built with DateTimeNullable (project wrapper type).
// Static type resolves to 'DateTimeNullable', not 'DateTime', so
// _isDateTimeName returns false for a DateTimeNullable.month access.
// However, if static type resolution fails (unresolved import in analysis
// sandbox), _isDateTimeName(null) returns true and the lint fires anyway.
String cacheKey(DateTimeNullable dt) {
  return '${dt.year}-${dt.month}-${dt.day}'; // LINT (when type unavailable) — cache key, not display
}
```

**Frequency:**
- Case A (internal key, interpolation not directly in a VariableDeclaration): Always.
- Case B (non-DateTime type with matching property names): Always when the type name is not `"DateTime"` or `"DateTime?"`.
- Case C (any custom wrapper): Always when static type resolution is unavailable in the analysis context.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the interpolated string is either an internal key (not user-facing) or the values do not come from a `DateTime` / `DateTime?` |
| **Actual** | `[avoid_manual_date_formatting] Manual date formatting is error-prone, ignores locale…` reported on the `StringInterpolation` node |

---

## AST Context

```
// Case A — nested in a return statement, not in a VariableDeclaration
ReturnStatement
  └─ StringInterpolation          ← node reported here
      ├─ InterpolationString ('$label|')
      ├─ InterpolationExpression
      │   └─ PrefixedIdentifier
      │       ├─ SimpleIdentifier (event)  — staticType: 'CalendarEvent'
      │       └─ SimpleIdentifier (month)  — property name in _dateProperties ✓
      ├─ InterpolationString ('|')
      └─ InterpolationExpression
          └─ PrefixedIdentifier
              ├─ SimpleIdentifier (event)
              └─ SimpleIdentifier (day)    — property name in _dateProperties ✓
```

`_countDateTimeProperties` counts 2 hits because:
1. `propertyName = "month"` → `_dateProperties.contains("month")` = true.
2. `_isDateTimeName("CalendarEvent")` → false (not "DateTime").
   BUT if static type is unavailable, `targetTypeName = null` → `_isDateTimeName(null)` = **true** (~line 1646).
3. Same for `"day"`.

Count = 2, threshold ≥ 2 reached (~line 1595). Then `_isNonDisplayContext` is
called. The parent of the `StringInterpolation` here is a `ReturnStatement`,
not an `IndexExpression` and not a `VariableDeclaration` — so none of the
non-display exemptions at lines ~1656–1683 match. `_isNonDisplayContext`
returns `false` → `reporter.atNode(node)` fires.

---

## Root Cause

### Hypothesis A: `_isDateTimeName(null) == true` is too permissive

The comment at line ~1643 states:

> "Unknown types (null) are treated as potentially DateTime to avoid false
> negatives when static type information is unavailable."

This conservative fallback was intended for cases where type resolution fails
due to incomplete analysis context. In practice it fires on any project-specific
type (`HebrewDate`, `DateTimeNullable`, `CalendarEvent`, etc.) whose properties
happen to share names with the `_dateProperties` set. The false-negative
avoidance trades away correctness for all custom calendar/date-like types.

### Hypothesis B: `_isNonDisplayContext` only checks direct-parent VariableDeclaration

The non-display exemption for variable names (~lines 1659–1668) checks
`node.parent is VariableDeclaration` and reads `parent.name.lexeme`. This
only works when the `StringInterpolation` is the direct initializer of a local
variable declaration. When the interpolation is:
- the argument to a function call (`buildEventDedupKey` returns it directly),
- the right-hand side of an assignment (`_dedupKey = '$x|$y'`),
- a map value literal (`{'dedupKey': '$m|$d'}`),

…the variable-name heuristic never fires even if the surrounding variable is
named `dedupKey`, `cacheKey`, `stableId`, etc.

### Hypothesis C: Property-name matching alone is insufficient for non-DateTime types

`_countDateTimeProperties` (~line 1612) checks `propertyName` membership in
`_dateProperties` AND `_isDateTimeName(targetTypeName)`. The DateTime check is
sound when types resolve, but the `null` fallback at line 1646 makes it fire
on any unresolved or custom type. There is no check that the property resolves
to a `DateTime` getter specifically — any `int` property named `month` on any
class counts.

---

## Suggested Fix

Two targeted changes in `internationalization_rules.dart`:

**1. Harden `_isDateTimeName` — do not treat unknown type as DateTime.**

Change line ~1646 from:

```dart
static bool _isDateTimeName(String? typeName) {
  if (typeName == null) return true; // ← fires on all unresolved types
  return typeName == 'DateTime' || typeName == 'DateTime?';
}
```

to:

```dart
static bool _isDateTimeName(String? typeName) {
  // Treat unknown type as non-DateTime to prefer false negatives over
  // false positives. The rule's message directs users to add locale
  // formatting — wrong advice for non-DateTime types.
  if (typeName == null) return false;
  return typeName == 'DateTime' || typeName == 'DateTime?';
}
```

Accept the trade-off: a small increase in false negatives (missed DateTime
without type info) is better than the current flood of false positives on
custom types.

**2. Widen `_isNonDisplayContext` to walk the ancestor chain for key-like names.**

The current check only matches a direct `VariableDeclaration` parent. Extend
it to also match when the interpolation is the return expression of a function
whose name contains an internal-key token, or when any ancestor within the
same expression statement is a variable/parameter named with one of the key
tokens. At minimum, walk one more level to handle `AssignmentExpression` and
function-argument contexts:

```dart
// Also exempt when the enclosing argument list's callee or the enclosing
// return-type annotation suggests an internal-ID context.
// Heuristic: if ANY ancestor VariableDeclaration or FunctionDeclaration
// within the same statement has a name containing a key token, skip.
AstNode? ancestor = node.parent;
while (ancestor != null && ancestor is! Statement) {
  if (ancestor is VariableDeclaration) {
    final name = ancestor.name.lexeme.toLowerCase();
    if (_internalKeyTokens.any(name.contains)) return true;
  }
  ancestor = ancestor.parent;
}
```

where `_internalKeyTokens` is the same set already used for `VariableDeclaration`
names (`key`, `cache`, `tag`, `hash`, `bucket`, `identifier`).

---

## Fixture Gap

The fixture at `example*/lib/ui/avoid_manual_date_formatting_fixture.dart`
should include:

1. **`return '$label|${event.month}|${event.day}'`** (return statement, not a
   local variable) — expect NO lint (internal key, non-display context)
2. **`HebrewDate` with `.month` / `.day` int getters, static type ≠ DateTime** —
   expect NO lint (non-DateTime type; locale formatting does not apply)
3. **`DateTimeNullable` where static type is unavailable in analysis** — expect
   NO lint (unknown type should no longer be assumed DateTime)
4. **`'${dt.year}-${dt.month}-${dt.day}'` assigned to `cacheKey`** — expect
   NO lint (internal key name in enclosing VariableDeclaration — already
   partially covered; regression guard)
5. **`'${d.year}/${d.month}/${d.day}'` where `d` is a real `DateTime`** —
   expect LINT (genuine manual date formatting for display)
6. **`'${d.year}-${d.month}-${d.day}'.toIso8601String().substring(0, 10)`** —
   expect LINT (existing `toIso8601String` + `substring` pattern; regression guard)
7. **`map['${d.year}-${d.month}']`** — expect NO lint (IndexExpression parent
   — already exempt; regression guard)

---

## Changes Made

Implemented both suggested fixes in `internationalization_rules.dart`:

1. **`_isDateTimeName(null)` now returns `false`** (was `true`). All three
   reported FP classes (Case A CalendarEvent, Case B HebrewDate, Case C
   DateTimeNullable) hinge on the `null → true` fallback firing on
   unresolved/custom types. Treating an unknown type as non-DateTime removes
   them. Trade-off accepted per the report: a real `DateTime` whose type fails
   to resolve is now a false negative, preferable to the FP flood on custom
   types.
2. **`_isNonDisplayContext` now walks the ancestor chain** (up to the enclosing
   named function) for a key-named `VariableDeclaration` or a key-named
   enclosing `FunctionDeclaration`/`MethodDeclaration`, replacing the
   direct-parent-only check. Added `_internalKeyTokens`
   (`key/cache/tag/hash/bucket/identifier/id`) and the `_nameHasKeyToken`
   helper. This exempts `return '...${d.month}...'` inside `buildEventDedupKey`
   / `cacheKey(...)` even for a real `DateTime`.

---

## Tests Added

- Rewrote `example/lib/internationalization/avoid_manual_date_formatting_fixture.dart`
  with `HebrewDate`/`CalendarEvent` custom types, key-builder functions, a
  map-subscript lookup (all NO lint), and real-`DateTime` display +
  `toIso8601String().substring` BAD cases.
- Scan CLI verified: the syntactic `toIso8601String().substring` BAD case
  fires; every custom-type and internal-key case is silent.

**Verification limitation:** the project scan CLI does not resolve `DateTime`
member types (target `staticType` is null), so after fix 1 the property-count
path cannot fire there and the real-`DateTime` display LINT case cannot be
positively confirmed via the CLI. In a consumer's analysis server (where
`dart:core` `DateTime` resolves to `"DateTime"`), that case still fires; the
fixture documents the intended behavior.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Finish Report (2026-06-09)

**Scope:** (A) Dart lint rules / analyzer plugin.

**Deep review:** Fix 1 is a one-line polarity change with a clear documented
trade-off. Fix 2's ancestor walk terminates at the enclosing function boundary
(returns at the first `FunctionDeclaration`/`MethodDeclaration`, breaks out of
closures) so it cannot climb into an unrelated outer scope; it only ever adds
exemptions, never new diagnostics. Rule file, tier, severity (WARNING),
`LintImpact` unchanged.

**Tests:** `dart test test/rules/ui/internationalization_rules_test.dart` →
all pass. Scan-CLI behavior verified as above (with the noted resolution
limitation).

**Maintenance:** CHANGELOG `[Unreleased]` Fixed bullet added. README/ROADMAP
unchanged (false-positive fix).

**Bug archived:** bugs/avoid_manual_date_formatting_false_positive_non_datetime_and_internal_keys.md
→ plans/history/2026.06/2026.06.09/avoid_manual_date_formatting_false_positive_non_datetime_and_internal_keys.md

**Finish report appended:** this file.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (as in Saropa Contacts toolchain, 2026-06-09)
- custom_lint version: N/A — saropa_lints uses analysis_server_plugin, not custom_lint
- Triggering project/file: Saropa Contacts 2026-06-09 — worked around with `// ignore: avoid_manual_date_formatting -- internal dedup key, not user-facing copy` (and similar rationale) on affected call sites
