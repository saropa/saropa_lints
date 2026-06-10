# BUG: `avoid_listview_without_item_extent` — Fires on `ListView.builder` whose item widget has intrinsically variable height (subtitle / expansion), where `itemExtent` is impossible to set correctly

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `avoid_listview_without_item_extent`
File: `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart` (line ~595, `runWithReporter`)
Severity: False positive
Rule version: v7 | Since: (rule `{v7}`) | Updated: v13.12.2

---

## Summary

The rule flags every `ListView.builder` that omits `itemExtent` / `prototypeItem` /
`itemExtentBuilder`, with the only exception being the `shrinkWrap + NeverScrollableScrollPhysics`
inline-list shape. It has no notion of whether the item widget *can* have a fixed extent. When the
item builder returns a widget whose height is intrinsically variable — a `ListTile`/`CheckboxListTile`
with an optional subtitle (1 vs 2 lines), or a collapsible `ExpansionTile`/panel that changes height
on tap — there is **no correct constant `itemExtent`** to add. A fixed extent would clip the 2-line
rows or the expanded panel; `itemExtentBuilder` cannot know the post-layout height of a self-sizing
child either. The diagnostic is unactionable: the suggested fix would introduce a visual bug.

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

**Emitter registration:** `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart:588` (LintCode), class `AvoidListViewWithoutItemExtentRule` at line 579.
**Rule registered in:** `lib/saropa_lints.dart:620` (`AvoidListViewWithoutItemExtentRule.new`).
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`.

---

## Reproducer

Minimal Dart code that triggers the bug:

```dart
import 'package:flutter/material.dart';

class VariableHeightList extends StatelessWidget {
  const VariableHeightList({super.key, required this.rows});
  final List<({String title, String? subtitle})> rows;

  @override
  Widget build(BuildContext context) {
    // LINT — but itemExtent is IMPOSSIBLE here: rows with a subtitle are
    // ~2 lines tall, rows without are ~1 line. Any constant extent clips
    // one of the two. prototypeItem picks ONE height for all. itemExtentBuilder
    // cannot measure a self-sizing ListTile.
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) {
        final r = rows[index];
        return ListTile(
          title: Text(r.title),
          subtitle: r.subtitle == null ? null : Text(r.subtitle!),
        );
      },
    );
  }
}

class ExpandingList extends StatelessWidget {
  const ExpandingList({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    // LINT — ExpansionTile changes height when tapped. A fixed itemExtent
    // would crop the expanded body. Genuinely unfixable.
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) =>
          ExpansionTile(title: Text(items[index]), children: const <Widget>[Text('body')]),
    );
  }
}
```

**Frequency:** Always, for any `ListView.builder` over self-sizing rows that lacks all three extent params and is not the `shrinkWrap + NeverScrollableScrollPhysics` shape.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the item widget is self-sizing, so no constant/computable extent exists; the diagnostic is unactionable. |
| **Actual** | `[avoid_listview_without_item_extent] ListView.builder should specify itemExtent, prototypeItem, or itemExtentBuilder ...` reported on the `ListView.builder` constructor name. |

---

## AST Context

```
MethodInvocation / ReturnStatement
  └─ InstanceCreationExpression (ListView.builder)        ← node walked
      ├─ ConstructorName (ListView.builder)               ← reporter.atNode target
      └─ ArgumentList
          ├─ NamedExpression (itemCount: …)
          └─ NamedExpression (itemBuilder: (c, i) => ListTile(... subtitle: …))
                                              ↑ return type is a self-sizing
                                                widget — never inspected by the rule
```

The rule only inspects the *named arguments* of the `ListView.builder` call
(`itemExtent`, `prototypeItem`, `itemExtentBuilder`, `shrinkWrap`, `physics`). It never looks at
the widget produced by `itemBuilder`, so it cannot tell a fixed-row list from a variable-row list.

---

## Root Cause

`runWithReporter` (lines 600–656) collects five booleans from the argument list and fires unless one
of the three extent params is present OR `isInlineNonScrolling` (`shrinkWrapTrue && neverScrollablePhysics`,
line 646–647) is true:

```dart
if (!hasItemExtent &&
    !hasPrototypeItem &&
    !hasItemExtentBuilder &&
    !isInlineNonScrolling) {
  reporter.atNode(node.constructorName, code);   // line 653
}
```

### Hypothesis A (confirmed): the rule has no signal for "item is self-sizing"

The detection is purely argument-presence based. A `ListView.builder` whose `itemBuilder` returns a
`ListTile` (optional subtitle), `CheckboxListTile`, `ExpansionTile`, or any custom row that wraps such
widgets has **no correct fixed extent**. The rule assumes a fixed extent always exists and is merely
omitted, which is false for the self-sizing case. The diagnostic message even claims `itemExtentBuilder`
covers "varying per-index heights" — but `itemExtentBuilder` requires the caller to *return* the height
per index, which is unknowable for a self-sizing child whose height depends on text wrapping / expansion
state computed during layout.

### Hypothesis B (rejected): user just forgot the param

For fixed-height rows this would be a true positive. The FP is specifically the self-sizing-item class,
which the rule cannot currently distinguish.

---

## Suggested Fix

Add a recognition step before reporting: when the `itemBuilder`'s returned widget is (or trivially wraps)
a known self-sizing tile, skip the diagnostic. Two pragmatic options, in order of preference:

1. **Builder-return inspection (preferred).** Resolve the `itemBuilder` `FunctionExpression`; if its body
   directly returns an `InstanceCreationExpression` whose type name is in a small self-sizing-widget
   allowlist (`ListTile`, `CheckboxListTile`, `RadioListTile`, `SwitchListTile`, `ExpansionTile`,
   `ExpansionPanel`), suppress. Mirror the existing `_knownWidgets`-set approach already used by
   `_WidgetCountVisitor` in `animation_rules.dart`. This is the same allowlist style the codebase
   already endorses.

2. **Project-allowlist escape hatch.** If builder-return inspection is judged too broad, expose a
   `saropa_lints` option (e.g. `allow_variable_height_listview: true`) so projects can opt a known-good
   surface out, the way other rules accept config. (A downstream `// ignore:` is the current workaround
   but every self-sizing list pays it.)

Both keep the true-positive coverage (fixed-height custom rows still fire) while removing the unactionable
case.

---

## Fixture Gap

The fixture at `example*/lib/widget/avoid_listview_without_item_extent_fixture.dart` should add:

1. `ListView.builder` whose `itemBuilder` returns `ListTile` with a nullable `subtitle` — expect **NO lint** (self-sizing).
2. `ListView.builder` whose `itemBuilder` returns `ExpansionTile` — expect **NO lint** (height changes on expand).
3. `ListView.builder` whose `itemBuilder` returns a `SizedBox(height: 56, …)` fixed-height row — expect **LINT** (a true positive that the fix must NOT regress).
4. `ListView.builder` whose `itemBuilder` returns `CheckboxListTile` with optional subtitle — expect **NO lint**.

---

## Real-World Occurrences (Saropa Contacts, v13.12.2)

| File:line | Item widget | Why itemExtent is wrong |
|---|---|---|
| `lib/components/contact_issues/audit_panel_email_shared.dart:103` | `CommonPanelExpandable` | expands/collapses — variable |
| `lib/components/contact_issues/audit_panel_phone_shared.dart:103` | `CommonPanelExpandable` | expands/collapses — variable |
| `lib/components/contact_issues/audit_panel_name_duplicate.dart:155` | `CommonPanelExpandable` | expands/collapses — variable |
| `lib/components/contact_group/contact_group_add_contact.dart:345` | `CommonListTile` (optional subtitle) | 1 vs 2 lines |
| `lib/components/family_group/family_group_add_contact.dart:387` | `CommonListTile` (optional subtitle) | 1 vs 2 lines |
| `lib/components/contact/detail_panels/timezone/contact_timezone_picker.dart:262` | custom `_buildTimezoneRow` + auto-detect row | mixed row heights (index 0 differs) |
| `lib/components/contact/picker/contact_pick_result_screen.dart:188` | `ContactDisplayNameAvatar` | avatar row height varies with name lines |
| `lib/components/contact_focus/focus_mode_group_picker.dart:215` | `_GroupTile` | variable per content |

`CommonListTile` declares an optional `subtitle` / `subtitleWidget` and a nullable `maxLines`
(`lib/components/primitive/common_list_tile.dart:38-114`), so its rendered height is not constant.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: >=3.10.7 <4.0.0 (per `d:/src/contacts/pubspec.yaml`)
- Flutter: >=3.44.0
- custom_lint version: n/a — saropa_lints runs as a native analyzer plugin (`analysis_server_plugin`), not via custom_lint
- Triggering project/file: `d:/src/contacts` — 8 of the 15 flagged `ListView.builder` sites

## Finish Report (2026-06-10)

Fixed in WS-4. Before reporting, the rule now inspects the `itemBuilder` return: when it builds (or branches to) a self-sizing item widget — ListTile/CheckboxListTile/RadioListTile/SwitchListTile/ExpansionTile/ExpansionPanel(List), or a project wrapper matching `*ListTile`/`*Expansion*`/`*Expandable` (CommonListTile, CommonPanelExpandable) — the diagnostic is suppressed, since no constant itemExtent is correct. Fixed-height rows (e.g. SizedBox(height: 56, ...)) still fire. Verified by the WS-4 unit test (ListTile/ExpansionTile/CommonListTile/CommonPanelExpandable exempt; SizedBox + plain Text flagged) and an end-to-end scan.
