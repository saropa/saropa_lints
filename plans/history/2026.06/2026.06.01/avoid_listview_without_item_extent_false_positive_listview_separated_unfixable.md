# BUG: `avoid_listview_without_item_extent` — Fires on `ListView.separated` but the recommended fix params don't exist on that constructor

**Status: Fixed**

Created: 2026-06-01
Rule: `avoid_listview_without_item_extent`
File: `lib/src/rules/widget/widget_layout_flex_scroll_rules.dart` (line ~597)
Severity: False positive
Rule version: v6 | Since: prior | Updated: v6

## Attribution (positive grep)

```
$ grep -rn "'avoid_listview_without_item_extent'" lib/src/rules/
lib/src/rules/widget/widget_layout_flex_scroll_rules.dart:581:    'avoid_listview_without_item_extent',
```

Rule lives in `saropa_lints`, no ambiguity with siblings.

## Summary

The rule visitor (lines 597–614) explicitly matches both `ListView.builder` AND `ListView.separated`:

```dart
if (typeName == 'ListView' &&
    (constructorName == 'builder' || constructorName == 'separated')) {
  // ... scans for itemExtent / prototypeItem / itemExtentBuilder
  if (!hasItemExtent && !hasPrototypeItem && !hasItemExtentBuilder) {
    reporter.atNode(node.constructorName, code);
  }
}
```

But `ListView.separated` has none of those three parameters in its constructor signature (Flutter SDK, `packages/flutter/lib/src/widgets/scroll_view.dart`). The rule's `correctionMessage` ("Add itemExtent for uniform height, prototypeItem for a single representative size, or itemExtentBuilder when each index can have a different extent") cannot be applied — none of these named parameters compile against `ListView.separated`.

## Reproducer

```dart
// Triggers the lint at the `separated` constructor name node.
// No fix from the rule's correctionMessage compiles here.
ListView.separated(
  scrollDirection: Axis.horizontal,
  itemCount: items.length,
  separatorBuilder: (_, _) => const SizedBox(width: 4),
  itemBuilder: (_, int i) => _Tile(item: items[i]),
)
```

Trying to apply the suggested fix:

```dart
// Fails to compile: "The named parameter 'itemExtent' isn't defined."
ListView.separated(
  itemExtent: 40,                       // ERROR
  // prototypeItem: const _Tile(...),   // ERROR — also not defined
  // itemExtentBuilder: (_, _) => 40,   // ERROR — also not defined
  scrollDirection: Axis.horizontal,
  itemCount: items.length,
  separatorBuilder: (_, _) => const SizedBox(width: 4),
  itemBuilder: (_, int i) => _Tile(item: items[i]),
)
```

## SDK evidence

From Flutter SDK `packages/flutter/lib/src/widgets/scroll_view.dart`, `ListView.separated` constructor:

```dart
ListView.separated({
  super.key,
  super.scrollDirection,
  super.reverse,
  super.controller,
  super.primary,
  super.physics,
  super.shrinkWrap,
  super.padding,
  required NullableIndexedWidgetBuilder itemBuilder,
  // ... findChildIndexCallback / findItemIndexCallback
  required IndexedWidgetBuilder separatorBuilder,
  required int itemCount,
  bool addAutomaticKeepAlives = true,
  bool addRepaintBoundaries = true,
  bool addSemanticIndexes = true,
  // ... cacheExtent / scrollCacheExtent / dragStartBehavior / etc.
}) : ...
```

No `itemExtent`, no `prototypeItem`, no `itemExtentBuilder`. Confirmed by reading SDK source under `$(dirname $(which flutter))/../packages/flutter/lib/src/widgets/scroll_view.dart` (~line 1503).

`ListView.builder` does have all three, so the rule is correct to fire on `.builder` without any of them.

## Why the rule fires on `.separated` anyway

The author may have assumed `.separated` is just sugar over `.builder` and accepts the same scroll-layout hints. It isn't. `.separated` is a distinct convenience constructor that splices in `separatorBuilder` at odd indices via `SliverChildBuilderDelegate`, and Flutter's `ListView.separated` constructor deliberately omits the extent-hint parameters because the alternating item/separator pattern breaks the uniform-extent assumption (an `itemExtent` would apply to BOTH items AND separators, which never have the same height).

## Root cause

`lib/src/rules/widget/widget_layout_flex_scroll_rules.dart:597`:

```dart
(constructorName == 'builder' || constructorName == 'separated')
```

The `|| constructorName == 'separated'` branch reports a diagnostic that cannot be fixed via the documented correction. Either:

1. Remove `'separated'` from the constructor allowlist entirely (rule only applies to `.builder`).
2. Keep `'separated'` but change the correction message to something achievable (e.g., "convert to `ListView.builder` + manual separator children if extent hints matter for this list").

Recommended: option 1. `.separated` exists specifically to avoid manual separator splicing in `.builder`; pushing users back to `.builder` defeats the convenience constructor's purpose. The rule should silently accept `.separated` as fine.

## Fixture gap

Test coverage in `test/` likely has a `.builder` case but no `.separated` case that should NOT fire. Add a fixture:

```dart
// fixtures/avoid_listview_without_item_extent_separated_ok.dart
ListView.separated(
  itemCount: items.length,
  separatorBuilder: (_, _) => const Divider(),
  itemBuilder: (_, int i) => Text('$i'),
);  // expect: no diagnostic
```

## Downstream impact

4 sites in `saropa/contacts` are pure-FP and need `// ignore: avoid_listview_without_item_extent` directives until the rule is fixed:

- `lib/components/contact/avatar/avatar_sheet_history_section.dart:86`
- `lib/components/contact/avatar/avatar_sheet_style_section.dart:101`
- `lib/components/contact/avatar/contact_status_horizontal_avatar_list.dart:328`
- `lib/components/contact/avatar/contact_status_horizontal_avatar_list.dart:387`

Each ignore carries a one-line rationale pointing at this bug report.

## Finish Report (2026-06-01)

Fix landed in the same commit that closed the sibling shrinkWrap+NeverScrollable false-positive bug — both bugs trace to the same rule and were addressed together.

**Resolution path:** Recommended option 1 from "Root cause" — `'separated'` removed from the constructor allowlist at `widget_layout_flex_scroll_rules.dart:609`. Rule now matches only `typeName == 'ListView' && constructorName == 'builder'`. Doc comment, problem message ({v7}), and `Since/Updated/Rule version` lines updated to make the exclusion explicit, with a pointer to this archived report.

**Full finish details** are in the sibling report at [avoid_listview_without_item_extent_false_positive_shrinkwrap_never_scrollable_inline_list.md](./avoid_listview_without_item_extent_false_positive_shrinkwrap_never_scrollable_inline_list.md#finish-report-2026-06-01) — files changed, tests added, CHANGELOG entry, and scan-CLI limitation note are recorded there.

**Status:** Fixed.
