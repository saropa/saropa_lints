# BUG: `avoid_retaining_disposed_widgets` — flags a `BuildContext` field on a `FlowDelegate` that is rebuilt with its owning widget

**Status: Open**

Created: 2026-10-29
Rule: `avoid_retaining_disposed_widgets`
File: `lib/src/rules/resources/memory_management_rules.dart` (class at line 1753)
Severity: False positive
Rule version: see diagnostic | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The rule treats every non-widget class that holds a `BuildContext` as a leak. A `FlowDelegate` is a short-lived render-time helper recreated on every `build` of its owning widget, so the reference cannot outlive the element.

---

## Attribution Evidence

```bash
grep -rn "'avoid_retaining_disposed_widgets'" lib/src/rules/
# lib/src/rules/resources/memory_management_rules.dart:1773:    'avoid_retaining_disposed_widgets',
```

**Rule class:** `AvoidRetainingDisposedWidgetsRule` (`lib/src/rules/resources/memory_management_rules.dart:1753`)
**Diagnostic as seen in Problems panel:** `[avoid_retaining_disposed_widgets] Non-widget class stores a reference to a Widget or State object. ... {v2} (line 59, col 3)` (source: saropa_lints)

---

## Reproducer

Standalone (needs the Flutter SDK). Real code: `lib/components/event/special_events/focus_card_hero_parallax.dart` lines 51-75 (`_HeroParallaxDelegate`, field on line 59, diagnostic at 59:22 / 59:3). The delegate is created inside `FocusCardHeroParallax.build` and lives exactly as long as the `Flow` render object.

```dart
import 'package:flutter/widgets.dart';

class ParallaxDelegate extends FlowDelegate {
  ParallaxDelegate({required this.itemContext});

  final BuildContext itemContext; // LINT — but this is the framework pattern for a Flow delegate

  @override
  void paintChildren(FlowPaintingContext context) {
    if (!itemContext.mounted) return;
    final RenderObject? item = itemContext.findRenderObject();
    if (item is RenderBox && item.hasSize) {
      context.paintChild(0);
    }
  }

  @override
  bool shouldRepaint(ParallaxDelegate old) => old.itemContext != itemContext;
}

Widget build(BuildContext context) =>
    Flow(delegate: ParallaxDelegate(itemContext: context), children: const <Widget>[SizedBox()]);
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic for a `FlowDelegate` / `CustomPainter` / `SingleChildLayoutDelegate` style delegate that is rebuilt with the widget and guards use with `context.mounted` |
| **Actual** | Diagnostic on the `BuildContext` field |

---

## AST Context

`ClassDeclaration(_HeroParallaxDelegate extends FlowDelegate)` > `FieldDeclaration` > `VariableDeclarationList(type: BuildContext)` > `VariableDeclaration(itemContext)`. The class has a `paintChildren(FlowPaintingContext)` override that reads `itemContext` after `itemContext.mounted`.

---

## Root Cause

`memory_management_rules.dart` `AvoidRetainingDisposedWidgetsRule.runWithReporter`: `_isWidgetClass` (line 1878) skips only classes whose superclass name is in `_widgetBaseClasses` (`StatelessWidget`, `State`, ...). `FlowDelegate`, `CustomPainter` and the layout delegates are not in the list. `_isWidgetRelatedType` (line 1862) then matches `BuildContext` (it is in `_widgetTypes`) and reports the field.

---

## Why the code is correct

`FlowDelegate` is a render-time helper owned by the `Flow` widget. A new delegate is built on every `build` of the owning widget, so it never outlives the element it was given. Flutter's own parallax recipe stores the item `BuildContext` in the delegate to call `findRenderObject()`. The code also checks `itemContext.mounted` before use.

## Affected project locations

- `lib/components/event/special_events/focus_card_hero_parallax.dart:59`

---

## Suggested Fix

Add the per-build delegate types (`FlowDelegate`, `CustomPainter`, `MultiChildLayoutDelegate`, `SingleChildLayoutDelegate`, `SliverGridDelegate`) to the skipped base classes, resolved by supertype element.

---

## Fixture Gap

- GOOD: `class D extends FlowDelegate { final BuildContext itemContext; }`
- BAD: `class Cache { final List<State> states = []; }`

---

## Environment

- saropa_lints version: 17.0.1-beta.2 (installed, hosted); rule logic cross-checked against the repo source (17.0.1-beta.3)
- Dart SDK: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project: Saropa contacts app (`/Users/craighathaway/Documents/src/contacts`)

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
