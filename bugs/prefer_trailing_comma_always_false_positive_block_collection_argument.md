# BUG: `prefer_trailing_comma_always` — fires on a block-formatted collection-literal sole argument that `dart format` leaves comma-free

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `prefer_trailing_comma_always`
File: `lib/src/rules/stylistic/stylistic_rules.dart` (line ~1122, ~1192)
Severity: False positive
Rule version: v4

---

## Summary

When a call's sole (or last) argument is a multi-line **collection literal**
(`{...}` / `[...]`), `dart format` block-formats it — the collection bracket hugs the
call paren and **no** trailing comma is required or wanted. The rule already exempts
this for a last-argument *function expression* (`_lastArgIsCallback`), but not for the
analogous *collection literal* case, so it demands a comma that `dart format` actively
rejects.

Proof: `dart format --output=show` reports **0 changes** on the flagged code; adding
the requested comma would force `dart format` to re-expand the argument onto its own
line — the opposite of "cleaner diffs".

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_trailing_comma_always'" lib/src/rules/
# lib/src/rules/stylistic/stylistic_rules.dart:1108:    'prefer_trailing_comma_always',
```

**Emitter registration:** `lib/src/rules/stylistic/stylistic_rules.dart:1108`
**Rule class:** `PreferTrailingCommaAlwaysRule` (`stylistic_rules.dart:1077`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#3`

---

## Reproducer

```dart
Set<DateTime> build(Iterable<DateTime> holidays) {
  // The sole argument is a set literal that dart format block-formats:
  // `(<DateTime>{` opens on the call line, `})` closes together.
  return Set<DateTime>.unmodifiable(<DateTime>{
    for (final DateTime h in holidays) _dateOnly(h),
  }); // LINT on `)` — but dart format reports 0 changes; no comma wanted
}
```

From `saropa_dart_utils`: `lib/datetime/business_calendar_utils.dart:27-29`.

Same shape with a list literal:

```dart
final widget = Padding(padding: EdgeInsets.all(8), child: Column(children: <Widget>[
  Text('a'),
  Text('b'),
])); // LINT on the inner `)` — but block-formatted, no comma wanted
```

**Frequency:** Always, when a call's last argument is a multi-line list/set/map literal.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `dart format` block-formats the collection argument and wants no trailing comma (`dart format` reports 0 changes) |
| **Actual** | `[prefer_trailing_comma_always] A multi-line argument list... missing a trailing comma` reported on the call's `)` |

This mirrors the Dart SDK `require_trailing_commas` lint, which exempts a last
argument that is a function expression **or** a collection literal — the
"block-formatted last argument" case. The quick fix (`AddTrailingCommaFix`) makes it
worse: it inserts a comma that `dart format` then uses to re-expand the layout.

---

## AST Context

```
ReturnStatement
  └─ MethodInvocation (Set.unmodifiable)
      └─ ArgumentList  ← addArgumentList fires; reports on rightParenthesis `)`
          └─ SetOrMapLiteral (<DateTime>{ ... })   ← the sole argument
              └─ ForElement
                  └─ MethodInvocation (_dateOnly)   (already has its own trailing comma)
```

The inner `SetOrMapLiteral` is fine (its last element has a trailing comma, so
`addSetOrMapLiteral` does not fire). Only the enclosing `ArgumentList` mis-fires.

---

## Root Cause

In `runWithReporter`, the `addArgumentList` branch
(`stylistic_rules.dart:1122-1139`) skips only when the last argument is a function
expression:

```dart
// Skip if last argument is a callback — the multi-line span
// comes from the function body, not from argument layout.
if (_lastArgIsCallback(node.arguments)) return;
```

and `_lastArgIsCallback` (line 1192) only recognizes `FunctionExpression`:

```dart
return expr is FunctionExpression;
```

`dart format` block-formats a trailing **collection literal** exactly like a trailing
function expression: the bracket hugs the paren and no trailing comma is added. The
rule lacks the parallel exemption, so a `ListLiteral` / `SetOrMapLiteral` last argument
slips past the skip and gets flagged.

(The `addListLiteral` / `addSetOrMapLiteral` branches already guard their own
`FunctionExpression`-last-element case at lines 1145 and 1161 — the same omission for
collection-as-argument is the gap here.)

---

## Suggested Fix

Broaden the argument-list exemption to cover any block-formatted last argument, not
just function expressions. In `stylistic_rules.dart`, replace the `_lastArgIsCallback`
check at line 1128 with a `_lastArgIsBlockFormatted` helper:

```dart
// dart format block-formats a trailing function expression OR collection
// literal: the brace/bracket hugs the call paren and no trailing comma is
// wanted. Matches the SDK require_trailing_commas exemption.
bool _lastArgIsBlockFormatted(NodeList<Expression> arguments) {
  final Expression last = arguments.last;
  final Expression expr = last is NamedExpression ? last.expression : last;
  return expr is FunctionExpression ||
      expr is ListLiteral ||
      expr is SetOrMapLiteral;
}
```

Keep the existing `_lastArgIsCallback` name as a thin alias if other call sites use it,
or rename at the single call site.

---

## Fixture Gap

The fixture for this rule should include:

1. `foo(<int>{ for (...) x, })` — sole set-literal argument, multi-line — expect **NO** lint
2. `foo(<int>[\n  1,\n  2,\n])` — sole list-literal argument, multi-line — expect **NO** lint
3. `foo(bar: <int>[\n  1,\n])` — named collection-literal last argument — expect **NO** lint
4. `foo(\n  a,\n  b\n)` — two scalar args, no block — expect **LINT** (regression guard)
5. `foo(() {\n  doThing();\n})` — function-expression last arg — expect **NO** lint (existing behavior)

Each "NO lint" case must also be verified stable under `dart format` (0 changes).

---

## Environment

- saropa_lints version: 13.12.3 (consuming project); local repo 13.12.4
- Dart SDK version: 3.12.1 (stable)
- Triggering project/file: `saropa_dart_utils` — `lib/datetime/business_calendar_utils.dart:27-29`
- `dart format --output=show --show=changed lib/datetime/business_calendar_utils.dart` → `0 changed`
