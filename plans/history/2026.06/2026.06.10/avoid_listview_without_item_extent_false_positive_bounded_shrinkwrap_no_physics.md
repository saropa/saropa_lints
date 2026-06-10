# BUG: `avoid_listview_without_item_extent` — FP-skip too narrow: fires on bounded / shrink-wrapped lists that omit an explicit `NeverScrollableScrollPhysics`

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `avoid_listview_without_item_extent`
File: `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart` (line ~642–653)
Severity: False positive
Rule version: v7 | Since: (rule `{v7}`) | Updated: v13.12.2

---

## Summary

The rule already exempts the inline-non-scrolling pattern, but only when **both**
`shrinkWrap: true` **and** `physics: NeverScrollableScrollPhysics()` are present
(`isInlineNonScrolling = shrinkWrapTrue && neverScrollablePhysics`, lines 646–647). Real
shrink-wrapped lists routinely set `shrinkWrap: true` **without** an explicit
`NeverScrollableScrollPhysics` (they nest inside an outer scroller, or are height-bounded by a
`ConstrainedBox`/`Flexible` and rely on default physics). In that shape, `shrinkWrap: true` already
forces eager layout of every child, so the lazy-extent benefit `itemExtent` exists to provide is
**impossible to obtain** — exactly the reason the existing exemption was added (see the rule's own
comment at lines 642–645 citing the archived shrinkwrap FP). Requiring the second condition leaves the
identical performance-irrelevant case still firing.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_listview_without_item_extent'" lib/src/rules/
# lib/src/rules/widget/widget_layout_flex_scroll_rules.dart:588:    'avoid_listview_without_item_extent',

# Negative — rule is NOT in the sibling drift-advisor repo
grep -rn "'avoid_listview_without_item_extent'" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart:588`, class at line 579.
**Rule registered in:** `lib/saropa_lints.dart:620`.
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`.

---

## Reproducer

```dart
import 'package:flutter/material.dart';

class ShrinkInColumn extends StatelessWidget {
  const ShrinkInColumn({super.key, required this.rows});
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    // shrinkWrap: true with NO explicit physics. Eager layout already
    // happens, so itemExtent's lazy benefit is unobtainable — same as the
    // exempted shrinkWrap+NeverScrollable shape, minus the redundant physics.
    return Column(
      children: <Widget>[
        ListView.builder(
          shrinkWrap: true,            // forces full layout of every child
          padding: EdgeInsets.zero,
          itemCount: rows.length,
          itemBuilder: (BuildContext c, int i) => Text(rows[i]), // LINT — but should NOT
        ),
      ],
    );
  }
}

class BoundedScroller extends StatelessWidget {
  const BoundedScroller({super.key, required this.rows});
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    // Height-bounded by ConstrainedBox; default physics. The list is a short
    // bounded preview, not a hot scroll path. itemExtent adds nothing.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (BuildContext c, int i) => Text(rows[i]), // LINT — borderline / unactionable
      ),
    );
  }
}
```

**Frequency:** Always, whenever `shrinkWrap: true` is set without `physics: NeverScrollableScrollPhysics()`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `shrinkWrap: true` alone should satisfy the inline-non-scrolling exemption (the eager-layout cost is already paid; `itemExtent` cannot make it lazy). No diagnostic. |
| **Actual** | `[avoid_listview_without_item_extent] …` fires because `neverScrollablePhysics` is false, so `isInlineNonScrolling` is false. |

---

## AST Context

```
InstanceCreationExpression (ListView.builder)
  └─ ArgumentList
      ├─ NamedExpression (shrinkWrap: true)          → shrinkWrapTrue = true
      ├─ NamedExpression (padding: …)
      ├─ NamedExpression (itemCount: …)
      └─ NamedExpression (itemBuilder: …)
         (no `physics:` argument → neverScrollablePhysics = false)
isInlineNonScrolling = shrinkWrapTrue && neverScrollablePhysics = (true && false) = false  ← fires
```

---

## Root Cause

Lines 642–653:

```dart
// Skip inline-non-scrolling lists: shrinkWrap forces eager layout of
// every child, so itemExtent's lazy-extent benefit is impossible ...
final bool isInlineNonScrolling =
    shrinkWrapTrue && neverScrollablePhysics;          // line 646–647

if (!hasItemExtent &&
    !hasPrototypeItem &&
    !hasItemExtentBuilder &&
    !isInlineNonScrolling) {                            // line 652
  reporter.atNode(node.constructorName, code);
}
```

### Hypothesis A (confirmed): the `&& neverScrollablePhysics` conjunct is too strict

The comment justifying the skip (lines 642–645) attributes the exemption entirely to **`shrinkWrap`
forcing eager layout** — `NeverScrollableScrollPhysics` plays no part in that argument. `shrinkWrap: true`
alone already defeats lazy extent; the physics value is orthogonal to whether `itemExtent` can help. The
conjunction therefore over-narrows the exemption: the very case the comment describes ("shrinkWrap forces
eager layout") still fires when physics is left at default.

### Hypothesis B (partial, separate concern): bounded non-shrinkWrap lists

The `ConstrainedBox(maxHeight:)`-bounded virtualizing list (no shrinkWrap) is a *weaker* FP — there
virtualization IS active, so `itemExtent` is a genuine (if minor) perf win. That case is better handled
by the variable-height-item fix (sibling bug) or left as a low-value true positive; this report's core
ask is only the shrinkWrap conjunct.

---

## Suggested Fix

Relax the exemption so `shrinkWrap: true` alone qualifies, since that is the condition the existing
comment actually relies on:

**Before** (line 646–647):
```dart
final bool isInlineNonScrolling =
    shrinkWrapTrue && neverScrollablePhysics;
```

**After:**
```dart
// shrinkWrap forces eager layout of every child regardless of physics, so
// itemExtent's lazy-extent benefit is unobtainable. The earlier
// `&& neverScrollablePhysics` over-narrowed this: a shrink-wrapped list
// with default physics pays the same eager cost. NeverScrollableScrollPhysics
// is now sufficient-but-not-required.
final bool isInlineNonScrolling = shrinkWrapTrue;
```

If the maintainer wants to keep flagging *scrollable* shrinkWrap lists (rare, and usually a different
anti-pattern the `avoid_shrink_wrap_expensive` rule already owns), gate instead on
`shrinkWrapTrue && !explicitAlwaysScrollablePhysics` — but the simpler `shrinkWrapTrue` matches the
stated rationale.

---

## Fixture Gap

`example*/lib/widget/avoid_listview_without_item_extent_fixture.dart` should add:

1. `ListView.builder(shrinkWrap: true, …)` with default physics — expect **NO lint** (regression guard for this fix).
2. `ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics(), …)` — expect **NO lint** (already passing; keep).
3. `ListView.builder(…)` plain scrolling, fixed-height rows, no shrinkWrap — expect **LINT** (true positive preserved).

---

## Real-World Occurrences (Saropa Contacts, v13.12.2)

| File:line | Shape |
|---|---|
| `lib/components/contact_issues/audit_panel_anniversary_match_missing.dart:168` | `shrinkWrap: true`, no physics, inside `Column` |
| `lib/components/contact_issues/audit_panel_email_shared.dart:103` | `shrinkWrap: true`, no physics, inside `Column` |
| `lib/components/contact_issues/audit_panel_phone_shared.dart:103` | `shrinkWrap: true`, no physics, inside `Column` |
| `lib/components/contact_issues/audit_panel_name_duplicate.dart:155` | `shrinkWrap: true`, no physics, inside `Column` |
| `lib/components/contact_issues/audit_panel_import_review.dart:204` | `shrinkWrap: true`, no physics, inside `Column` |
| `lib/components/contact/import/calendar_attendee_preview_dialog.dart:194` | `shrinkWrap: true` + `ConstrainedBox(maxHeight: 300)` |

(The three `*_shared` / `name_duplicate` panels overlap with the variable-height-item sibling bug
because their items are `CommonPanelExpandable`; either fix suppresses them.)

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: >=3.10.7 <4.0.0
- Flutter: >=3.44.0
- custom_lint version: n/a — native analyzer plugin (`analysis_server_plugin`)
- Triggering project/file: `d:/src/contacts` — 6 flagged sites of this shape
