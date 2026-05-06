<!--
  Completed bug archive (2026-04-29).
  Source: bugs/avoid_nested_scrollables_conflict_false_positive_cross_axis_nesting.md
-->

# BUG: `avoid_nested_scrollables_conflict` — Cross-Axis Nesting Wrongly Flagged

**Status: Closed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-29
Rule: `avoid_nested_scrollables_conflict`
File: `lib/src/rules/widget/scroll_rules.dart` (line ~193)
Severity: False positive
Rule version: v4 | Since: v1.7.9 | Updated: v4.13.0

---

## Summary

The rule flags any nested scrollable that lacks an explicit `physics:` argument, regardless of axis. A horizontal `SingleChildScrollView` nested inside a vertical `SingleChildScrollView` (cross-axis) does **not** cause a gesture conflict — Flutter's gesture arena routes horizontal drags to the horizontal scroller and vertical drags to the vertical one. The rule should ignore nested scrollables when the inner `scrollDirection` differs from the outer scroll axis.

The current correction message is also misleading for cross-axis cases: applying `NeverScrollableScrollPhysics` to the inner horizontal scroller would defeat its entire purpose (allowing horizontal scrolling of overflowing content) without any gesture-conflict benefit.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_nested_scrollables_conflict'" lib/src/rules/
# lib/src/rules/widget/scroll_rules.dart:209:    'avoid_nested_scrollables_conflict',

# Negative — rule is NOT in sibling repos
grep -rn "'avoid_nested_scrollables_conflict'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches (exit 1)
```

**Emitter registration:** `lib/src/rules/widget/scroll_rules.dart:209`
**Rule class:** `AvoidNestedScrollablesConflictRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (saropa_lints native plugin)

---

## Reproducer

Minimal cross-axis nesting that the rule wrongly flags. Real source:
`d:/src/contacts/lib/components/primitive/expandable_card/expandable_listener_card.dart:322-345`.

```dart
// VERTICAL outer scrollview containing a Column whose children include
// a HORIZONTAL inner scrollview for overflow text on a button.
// No gesture conflict — different axes route through separate arenas.
@override
Widget build(BuildContext context) {
  return SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    // outer: vertical (default scrollDirection)
    child: Column(
      children: <Widget>[
        SingleChildScrollView(
          // inner: HORIZONTAL — different axis from outer
          scrollDirection: Axis.horizontal,
          // LINT — but should NOT lint (false positive on cross-axis)
          child: const Text('long overflowing button label'),
        ),
      ],
    ),
  );
}
```

**Frequency:** Always — fires whenever an inner scrollable on a different axis lacks an explicit `physics:` argument.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when inner `scrollDirection` differs from outer scroll axis (default vertical for `SingleChildScrollView`/`ListView`/`CustomScrollView`, or whatever the outer's `scrollDirection` resolves to). |
| **Actual** | `[avoid_nested_scrollables_conflict] Nested scrollable without explicit physics causes gesture conflicts.` reported at the inner scrollable. |

---

## AST Context

```
MethodDeclaration (build)
  └─ Block
      └─ ReturnStatement
          └─ InstanceCreationExpression (SingleChildScrollView, vertical)   ← outer
              └─ ArgumentList
                  └─ NamedExpression (child)
                      └─ InstanceCreationExpression (Column)
                          └─ ArgumentList
                              └─ NamedExpression (children)
                                  └─ ListLiteral
                                      └─ InstanceCreationExpression (SingleChildScrollView, horizontal)  ← node reported here
```

---

## Root Cause

`_NestedScrollableVisitor._checkScrollable` (lines 262–280) inspects only:

1. Whether the type is in `_scrollableTypes`
2. Whether *any* ancestor is also a scrollable (`_isInsideScrollable` walks `node.parent` looking for a type in `_scrollableTypes`)
3. Whether the inner argument list contains a `physics:` named argument

It never reads `scrollDirection` on either the inner or the outer scrollable. Cross-axis nesting (one vertical + one horizontal) does not produce a gesture conflict in Flutter — the gesture arena resolves drags by axis. So the rule's premise ("nested scrollable causes gesture conflict") only holds when the two scroll axes are the same.

### Hypothesis A: Add axis-mismatch escape

Resolve `scrollDirection` on the inner and outer creation expressions:

- Default for `SingleChildScrollView`, `ListView`, `CustomScrollView`, `GridView` is `Axis.vertical`.
- `PageView` defaults to `Axis.horizontal`.
- If either explicitly passes `scrollDirection: Axis.X`, that wins.

If the inner axis differs from the outer axis, return without reporting. This matches Flutter runtime behavior and removes the FP without weakening same-axis detection.

### Hypothesis B: Honor `scrollDirection` only on the inner, assume parent vertical

Cheaper but wrong: if the parent is itself a horizontal scroller (e.g. a horizontal `PageView` containing a horizontal `ListView`), this would miss a real conflict.

Hypothesis A is the right fix.

---

## Suggested Fix

In `lib/src/rules/widget/scroll_rules.dart`:

1. Extract a helper `Axis _scrollAxisOf(InstanceCreationExpression node)` that returns:
   - The literal value of any `scrollDirection: Axis.X` argument, if present (parse the `PrefixedIdentifier` / `PropertyAccess`).
   - `Axis.horizontal` for `PageView` when no explicit `scrollDirection`.
   - `Axis.vertical` otherwise.
2. In `_isInsideScrollable`, when an ancestor scrollable is found, return *that node*, not just `bool`.
3. In `_checkScrollable`, after locating the ancestor scrollable, compare `_scrollAxisOf(inner)` to `_scrollAxisOf(outer)`. If they differ, return without reporting.

Update the rule's docstring to clarify it targets same-axis nesting. Update the correction message to acknowledge that cross-axis nesting is fine and that for same-axis cases either `NeverScrollableScrollPhysics()` or another explicit physics value is acceptable.

---

## Fixture Gap

The fixture at `example/lib/scroll/avoid_nested_scrollables_conflict_fixture.dart` should include:

1. **Vertical outer + horizontal inner, no physics** — expect NO lint (cross-axis is safe)
2. **Horizontal outer (`PageView`) + vertical inner, no physics** — expect NO lint
3. **Horizontal outer + horizontal inner (same axis)** — expect LINT
4. **`scrollDirection: Axis.horizontal` written explicitly on outer + same on inner** — expect LINT
5. **Cross-axis with explicit `physics:` on inner** — expect NO lint (already covered by physics check, but verify)

---

## Changes Made

- `lib/src/rules/widget/scroll_rules.dart`: `_NestedScrollableVisitor` now finds the **nearest** scrollable ancestor, resolves each side’s scroll axis (`PageView` defaults horizontal; other covered types default vertical; honors literal `scrollDirection: Axis.*`), and skips the diagnostic when axes differ. Unknown non-literal `scrollDirection` remains conservative (still eligible for the lint). Lint text bumped to **v4**; docstring and correction message updated for same-axis vs cross-axis.
- `example/lib/scroll/avoid_nested_scrollables_conflict_fixture.dart`: Added fixture classes for cross-axis (no `expect_lint`), same-axis horizontal/vertical (`expect_lint`), cross-axis with explicit `physics`, and `PageView` + `ListView`.
- `test/avoid_nested_scrollables_conflict_rule_test.dart`: Slice-based tests on fixture `expect_lint` markers plus registration check.
- `CHANGELOG.md` **[Unreleased]**, `analysis_options.yaml` inline comment: user-facing summary of the behavior change (apply when cutting a release or isolating hunks).

---

## Tests Added

- `test/avoid_nested_scrollables_conflict_rule_test.dart` — registration, fixture presence, and per-class `expect_lint` expectations for cross-axis vs same-axis scenarios.

---

## Commits

- Search git history for subject: `fix: avoid_nested_scrollables_conflict skip cross-axis nesting`.

---

## Environment

- saropa_lints version: 12.8.4
- Dart SDK version: Flutter 3.x channel
- custom_lint version: native analyzer plugin (no custom_lint)
- Triggering project/file: `d:/src/contacts/lib/components/primitive/expandable_card/expandable_listener_card.dart` (lines 335–339)
