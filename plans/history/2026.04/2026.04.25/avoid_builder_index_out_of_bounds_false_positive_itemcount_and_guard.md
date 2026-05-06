# BUG: `avoid_builder_index_out_of_bounds` — Reports when `itemCount` and guard already bound access

**Status: Closed (repo ≥ 12.4.5)**  
**Archived from `bugs/`:** 2026-04-25

Created: 2026-04-24  
Rule: `avoid_builder_index_out_of_bounds`  
File: `lib/src/rules/widget/widget_layout_constraints_rules.dart` (`AvoidBuilderIndexOutOfBoundsRule`)  
Rule version: **v7** (diagnostic tag in message)

---

## Summary

In `contacts` audit panels, `ListView.builder` uses `itemCount: groups.length`, an `if (index < 0 || index >= groups.length) return emptyWidget;` guard, and only then `groups[index]`. The rule still reports that `itemBuilder` accesses the list without a bounds check. Reading the current rule implementation, `itemCount` binding to `groups.length` should mark `groups` as safe, and the explicit `index >= groups.length` check should also satisfy `hasLength`. Either the published `saropa_lints` version used by the app differs from the local source, or another condition in the loop still reports. Standard `// ignore:` and `// ignore_for_file:` forms did not clear the diagnostic in the IDE/`read_lints` (custom_lint may use a different suppression path).

---

## Resolution (2026-04-25)

1. **Minimal reproducer** (`itemCount: groups.length`, compound guard, `groups[index]` inside `try`) was simulated against current logic: **no report** — `body.toSource()` includes the guard; `itemCount` and length-check paths both apply.
2. **Likely real cause when a warning persists:** another list is subscripted with the same index (e.g. `ids[index]`) while only `groups` is guarded or tied to `itemCount`. The rule requires a **per-list** signal; see `test/avoid_builder_index_out_of_bounds_behavior_test.dart` (`parallel second list` case).
3. **Consumers on a version before 12.4.5:** upgrade; older releases may lack the `itemCount: list.length` skip or other refinements.
4. **Carousel-style APIs** using `realIndex` (third callback parameter): v7 extends subscript detection to `idx`, `realIndex`, and `itemIndex` so guarded `items[realIndex]` is recognized.
5. **Documentation cleanup:** A duplicate `avoid_expanded_outside_flex` dartdoc block had sat above `AvoidBuilderIndexOutOfBoundsRule` in `widget_layout_constraints_rules.dart`; it was removed and the full Expanded/Flexible dartdoc was attached to `AvoidExpandedOutsideFlexRule` in `widget_layout_flex_scroll_rules.dart` (replacing an incorrect Stack-only stub there).

---

## Attribution Evidence

```text
grep -rn "'avoid_builder_index_out_of_bounds'" lib/src/rules/
```

Search by rule id in `widget_layout_constraints_rules.dart` (`AvoidBuilderIndexOutOfBoundsRule`).

---

## Reproducer (minimal pattern)

Consumer: `d:\src\contacts\lib\components\contact_issues\audit_panel_email_shared.dart` (same structure in `audit_panel_phone_shared.dart`, `audit_panel_name_duplicate.dart`).

Pattern:

```dart
ListView.builder(
  shrinkWrap: true,
  itemCount: groups.length,
  itemBuilder: (BuildContext context, int index) {
    if (index < 0 || index >= groups.length) {
      return emptyWidget;
    }
    try {
      final ContactMatchGroup group = groups[index];
      // ...
    } on Object catch (e, st) { ... }
  },
)
```

Expected: no warning (itemCount matches `groups.length`, and guard before `groups[index]`).  
Observed: `[avoid_builder_index_out_of_bounds]` at reported line/column (often near `shrinkWrap` / offset line in Problems panel).

---

## Environment

- `saropa_lints: ^12.4.2` in `pubspec.yaml` (package `saropa` / app `contacts`).  
- Local `saropa_lints` repo at `D:\src\saropa_lints` shows skip logic when `itemCount` is `list.length` and when `hasComparisonOp` + `list.length` appear in the itemBuilder body; behavior should be re-checked against the **exact** pub-resolved artifact.

---

## Suggested investigation

1. Confirm whether `pub` cache `saropa_lints 12.4.2` matches this repo’s `AvoidBuilderIndexOutOfBoundsRule` (diff `widget_layout_constraints_rules.dart`).  
2. If logic matches, verify `NamedExpression` parent `ArgumentList` and `_getItemCountBoundLists` for this `ListView.builder` shape (comments / `shrinkWrap` before `itemCount` should not matter).  
3. If `body.toSource()` omits the leading `if` guard in some AST shapes, fix extraction or document.  
4. Document how consumers should suppress via `// ignore` for custom_lint-registered rules if current ignores are ignored.

---

## Workaround (app)

- Temporarily set `avoid_builder_index_out_of_bounds: false` under `plugins: saropa_lints: diagnostics:` (loses project-wide protection), or live with the warning until the rule is fixed.
