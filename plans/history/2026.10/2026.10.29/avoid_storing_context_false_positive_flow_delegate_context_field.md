# BUG: `avoid_storing_context` — flags a `BuildContext` field on a `FlowDelegate` that is rebuilt with its owning widget and guarded with `context.mounted`

**Status: Open**

Created: 2026-10-29
Rule: `avoid_storing_context`
File: `lib/src/rules/core/context_rules.dart` (class at line 54)
Severity: False positive
Rule version: see diagnostic | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The rule reports every field whose declared type contains `BuildContext`, except function types. A `FlowDelegate` (also `CustomPainter`, layout delegates) is a short-lived object recreated on every `build` and cannot outlive its widget.

---

## Attribution Evidence

```bash
grep -rn "'avoid_storing_context'" lib/src/rules/
# lib/src/rules/core/context_rules.dart:71:    'avoid_storing_context',
```

**Rule class:** `AvoidStoringContextRule` (`lib/src/rules/core/context_rules.dart:54`)
**Diagnostic as seen in Problems panel:** `[avoid_storing_context] Storing a BuildContext in a field or variable for later use is dangerous ... {v4} (line 59, col 22)` (source: saropa_lints)

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

`context_rules.dart` (line 84, `context.addFieldDeclaration`): the only exemption is `node.fields.type is GenericFunctionType`. `_isContextType` (line 125) is a text match on the type source. No check of the enclosing class (its supertype) or of a `mounted` guard.

---

## Why the code is correct

`FlowDelegate` is a render-time helper owned by the `Flow` widget. A new delegate is built on every `build` of the owning widget, so it never outlives the element it was given. Flutter's own parallax recipe stores the item `BuildContext` in the delegate to call `findRenderObject()`. The code also checks `itemContext.mounted` before use.

## Affected project locations

- `lib/components/event/special_events/focus_card_hero_parallax.dart:59`

---

## Suggested Fix

Exempt fields in classes that extend Flutter delegate types that are recreated per build (`FlowDelegate`, `CustomPainter`, `MultiChildLayoutDelegate`, `SingleChildLayoutDelegate`, `SliverGridDelegate`), resolved by supertype element, not by name. Optionally also exempt when the class reads the field only after a `.mounted` check.

---

## Fixture Gap

- GOOD: `class D extends FlowDelegate { final BuildContext itemContext; ... }`
- BAD: `class Service { BuildContext? _ctx; }` (long-lived non-widget object)

---

## Environment

- saropa_lints version: 17.0.1-beta.2 (installed, hosted); rule logic cross-checked against the repo source (17.0.1-beta.3)
- Dart SDK: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project: Saropa contacts app (`/Users/craighathaway/Documents/src/contacts`)

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
