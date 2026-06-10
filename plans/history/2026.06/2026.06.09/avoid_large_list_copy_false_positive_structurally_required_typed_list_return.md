# BUG: `avoid_large_list_copy` — Fires on `.toList()` Inside Switch Arms and Other Structurally-Required Contexts Not Covered by `_isToListRequired`

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_large_list_copy`
File: `lib/src/rules/core/performance_rules.dart` (line ~2131)
Severity: False positive
Rule version: v4

---

## Summary

`avoid_large_list_copy` fires on `.map(...).toList()` expressions whose result is
structurally required to be a concrete `List` — specifically when the `.toList()` appears
as an arm of a `switch` expression or `switch` statement, or as the value of a record /
tuple field. The rule's `_isToListRequired` exemption helper climbs parent AST nodes to
detect mandatory-`List` contexts (return statements, assignments, argument lists, etc.) but
its wrapper-climbing loop (`context_rules.dart` lines 2196–2217) does not unwrap
`SwitchExpressionCase`, `SwitchCase`, or record literal fields, so the parent seen by the
exemption check is the switch arm node rather than the enclosing structure that demands a
`List`. The rule message itself states "structurally-required `.toList()` are exempt", but
the exemption does not fire for these forms. One getter in Saropa Contacts
(`conversion_utils.dart`, ~30 switch arms) produced 62 hits; all were worked around with
`// ignore: avoid_large_list_copy -- structurally-required List<T> return` on 2026-06-09.

---

## Attribution Evidence

Positive attribution — rule IS defined in `saropa_lints`:

```
# Positive — rule IS defined here
grep -rn "'avoid_large_list_copy'" lib/src/rules/
lib/src/rules/core/performance_rules.dart:2131: 'avoid_large_list_copy',
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:2131`
**Rule class:** `AvoidLargeListCopyRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#N`
(the IDE analysis-server plugin; negative attribution against sibling repos not required for this owner label)

---

## Reproducer

```dart
// Case 1 — switch expression arm (most common in Saropa Contacts)
// List<String> return type makes .toList() structurally required,
// but the switch arm parent is SwitchExpressionCase, not ReturnStatement.
List<String> get availableKeys => switch (category) {
  Category.units => UnitModel.units.map((u) => u.key).toList(),   // LINT — should NOT lint
  Category.types => TypeModel.types.map((t) => t.key).toList(),   // LINT — should NOT lint
  _ => const <String>[],
};

// Case 2 — expression-body getter (should already be exempt via ExpressionFunctionBody,
// but recorded here for completeness if the parent walk is broken by an intervening node)
List<String> get unitKeys =>
    UnitModel.units.map((u) => u.key).toList();   // may lint depending on parent walk

// Case 3 — field initializer with explicit List<T> type
final List<String> keys = someIterable.map((e) => e.name).toList();   // LINT — VariableDeclaration should exempt but does not if wrapped by field declaration vs local variable

// Case 4 — record field / tuple value (Dart 3 records)
(List<int>, String) buildResult() {
  return (items.map((i) => i.id).toList(), 'ok');   // LINT — record element parent not unwrapped
}
```

**Frequency:** Always — every `.map(...).toList()` (and `where/expand/skip` chain + `.toList()`)
whose parent AST node after the wrapper-climb is a `SwitchExpressionCase`,
`SwitchCase`, or record-related node rather than one of the handled parent types.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the enclosing getter/method return type is `List<T>`, so `.toList()` is mandatory; a lazy `Iterable` would be a compile error |
| **Actual** | `[avoid_large_list_copy] List.from() and toList() allocate a new list and copy every element … {v4}` reported on the `.toList` method name at each switch arm |

---

## AST Context

For Case 1 (switch expression arm):

```
MethodDeclaration (availableKeys — getter, return type List<String>)
  └─ ExpressionFunctionBody
      └─ SwitchExpression
          └─ SwitchExpressionCase
              └─ MethodInvocation (.toList)           ← node reported here
                  └─ target: MethodInvocation (.map(...))
```

The `_isToListRequired` wrapper-climbing loop (lines 2196–2217 in `performance_rules.dart`)
stops when it encounters `SwitchExpressionCase` because that node type is not listed in the
`ParenthesizedExpression | ConditionalExpression | NamedExpression` unwrap set. The `break`
at line 2217 exits the loop with `parent = SwitchExpressionCase`. None of the subsequent
checks (lines 2221–2266) match `SwitchExpressionCase`, so `_isToListRequired` returns
`false` and the diagnostic fires.

The enclosing `ExpressionFunctionBody` (which WOULD exempt the pattern via line 2222) is
never reached.

---

## Root Cause

`AvoidLargeListCopyRule._isToListRequired` (`performance_rules.dart`, lines 2189–2267) climbs
the parent chain to find the nearest semantically meaningful ancestor. The climbing loop
(lines 2196–2217) is written as an explicit allowlist of transparent wrapper node types:

```dart
if (parent is ParenthesizedExpression ||
    parent is ConditionalExpression ||
    parent is NamedExpression) {
  current = parent;
  parent = parent.parent;
  continue;
}
break;   // stops here for any unrecognized parent type
```

**Any AST node type absent from this allowlist terminates the climb.** The following
structurally-transparent parents are missing and cause the exemption to fail:

| Missing node type | Pattern it blocks |
|---|---|
| `SwitchExpressionCase` | Dart 3 switch expression arm: `switch (x) { A => items.map(...).toList(), ... }` |
| `SwitchCase` | Classic switch statement arm with expression body |
| `RecordLiteral` element / `MapLiteralEntry` key (already handled for values) | Record tuple field `(items.map(...).toList(), y)` |
| `YieldStatement` | `yield items.map(...).toList()` inside a sync* generator with `List<T>` element type |

For the Saropa Contacts case: a `List<String>` expression-body getter containing a
`switch` expression with ~30 arms, each producing a `.map(...).toList()`. The `_isToListRequired`
check sees `SwitchExpressionCase` as the parent, hits `break`, then tests none of the
exempt parent cases — returning `false`. The reporter fires 62 times (once per `.toList`
invocation across the arms), even though the `ExpressionFunctionBody` two levels up would
have exempted every one of them.

The rule's own diagnostic message and doc comment state: "structurally-required `.toList()` are
exempt" and show a `List<int> getPositive() => list.where(...).toList()` example. The
claimed exemption is real for simple expression-body forms (line 2222 handles
`ExpressionFunctionBody` directly), but the climb never reaches it when an intermediate
switch or record node sits between the `.toList()` and the function body.

---

## Suggested Fix

Extend the wrapper-climbing `while` loop in `_isToListRequired` (lines 2210–2216) to also
unwrap AST nodes that are structurally transparent with respect to the List requirement:

```dart
// Add to the existing unwrap condition:
if (parent is ParenthesizedExpression ||
    parent is ConditionalExpression ||
    parent is NamedExpression ||
    parent is SwitchExpressionCase ||   // switch expression arm
    parent is SwitchCase ||              // classic switch arm
    parent is YieldStatement) {          // sync* generator yield
  current = parent;
  parent = parent.parent;
  continue;
}
```

For `RecordLiteral` elements: a `.toList()` inside a record literal at a position typed
`List<T>` should also be exempt. The record field check is more nuanced (requires comparing
against the declared record type), but the common case — a record element whose enclosing
function return type is a record containing `List<T>` — can be handled by continuing the
climb past `RecordLiteral` and trusting `ExpressionFunctionBody`/`ReturnStatement` to do
the final exemption check.

No behavioral change for the existing exempt cases (`ReturnStatement`,
`ExpressionFunctionBody`, `VariableDeclaration`, `AssignmentExpression`,
`ArgumentList`, `CascadeExpression`, etc.) — those checks remain after the loop and
continue to fire correctly.

---

## Fixture Gap

The fixture at `example*/lib/core/performance_rules_fixture.dart` (or equivalent) should include:

1. **`switch` expression arm inside `List<T>` expression-body getter** — expect NO lint.
   `List<String> get keys => switch (x) { A => items.map((e) => e.k).toList(), _ => [] };`
2. **`switch` expression arm inside a `List<T>` return-type method with a `return switch (...)`** — expect NO lint.
3. **Classic `switch` statement with `return items.map(...).toList();` in each case** — expect NO lint
   (already covered by `ReturnStatement` check, but verify the case body does not break the climb).
4. **Record literal field typed `List<T>`** — expect NO lint.
   `(List<int>, String) f() => (items.map((e) => e.id).toList(), 'x');`
5. **Genuinely avoidable `.toList()` — result stored in `Iterable<T>` local, never indexed** — expect LINT.
   `final Iterable<String> it = items.map((e) => e.name).toList();`
6. **`.toList()` in a loop body with no structural requirement** — expect LINT.

---

## Changes Made

Extended the wrapper-climbing loop in `_isToListRequired`
(`performance_rules.dart`). The report's suggested fix was incomplete — it
added only `SwitchExpressionCase`, but unwrapping that lands on
`SwitchExpression`, which is also unhandled and would still `break` into a false
positive. The implemented fix unwraps all three transparent nodes:

- `SwitchExpressionCase` — the arm wrapper
- `SwitchExpression` — its parent, so the climb reaches the enclosing
  `ExpressionFunctionBody`/`ReturnStatement`
- `RecordLiteral` — a `.toList()` at a `List<T>` record position flows to the
  enclosing return/assignment

Also added a post-loop `if (parent is YieldStatement) return true;` so a
`.toList()` yielded from a `sync*`/`async*` generator (List element type) is
treated as required, matching `ReturnStatement`.

Classic `SwitchCase` was intentionally NOT added: a classic switch body holds
statements, and `return x.toList();` inside a case is already exempt via the
existing `ReturnStatement` check.

---

## Tests Added

- `example/lib/performance/avoid_large_list_copy_fixture.dart`: added four NO-lint
  cases — switch-expression arm in a `List<int>` getter (`_good794n`), switch in
  a `return` (`_good794o`), returned record field (`_good794p`), and a `sync*`
  `yield` (`_good794q`).
- Scan CLI verified: the only `avoid_large_list_copy` hit is the existing
  discarded-`.toList()` BAD case; all four new structurally-required cases are
  clean.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Finish Report (2026-06-09)

**Scope:** (A) Dart lint rules / analyzer plugin.

**Deep review:** The change is additive to an existing allowlist climb; the
loop still terminates (each iteration moves `parent` up one level). No new
recursion. Scoped to nodes that are genuinely transparent w.r.t. the List
requirement. `RecordLiteral`/`YieldStatement` exemptions accept a small
false-negative risk (a record field or yield typed `Iterable<T>` would be
exempted) in exchange for removing the FP flood — the safe direction for a
copy-avoidance INFO rule. Rule file, tier, severity (INFO), `LintImpact`
unchanged.

Noted but out of scope: the `List.from(...)` branch (untouched by this fix)
does not fire in the scan CLI; that is a pre-existing, separate behavior in the
`InstanceCreationExpression` visitor, unrelated to the reported `.toList()`
switch-arm symptom.

**Tests:** `dart test test/rules/core/performance_rules_test.dart` → all pass.
Scan-CLI behavior verified as above.

**Maintenance:** CHANGELOG `[Unreleased]` Fixed bullet added. README/ROADMAP
unchanged (false-positive fix).

**Bug archived:** bugs/avoid_large_list_copy_false_positive_structurally_required_typed_list_return.md
→ plans/history/2026.06/2026.06.09/avoid_large_list_copy_false_positive_structurally_required_typed_list_return.md

**Finish report appended:** this file.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (project Dart SDK — see Saropa Contacts pubspec)
- custom_lint version: N/A (saropa_lints is a native analysis_server_plugin, not custom_lint)
- Triggering project/file: Saropa Contacts — `lib/utils/conversion_utils.dart`,
  ~62 hits in one getter with ~30 switch expression arms; worked around with
  `// ignore: avoid_large_list_copy -- structurally-required List<T> return` on 2026-06-09
