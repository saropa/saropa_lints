# BUG: `avoid_retaining_disposed_widgets` — Fires on a Widget subclass that extends a Flutter widget base not in the fixed name list

**Status: Open**

Created: 2026-10-29
Rule: `avoid_retaining_disposed_widgets`
File: `lib/src/rules/resources/memory_management_rules.dart` (line ~1738; `_isWidgetClass` line 1878; `_widgetBaseClasses` line 1800)
Severity: False positive
Rule version: v2 | Since: unknown | Updated: unknown

---

## Summary

The rule exempts "widget classes" by comparing the DIRECT superclass name with a fixed list (`StatelessWidget`, `StatefulWidget`, `State`, ...). A class that is a `Widget` through another Flutter base (here `PopupMenuEntry<dynamic>`, which extends `StatefulWidget`) is treated as a non-widget class, and its `Widget` field is reported. A widget may hold child widgets, so no diagnostic is correct.

---

## Attribution Evidence

```bash
grep -rn "'avoid_retaining_disposed_widgets'" lib/src/rules/
# lib/src/rules/resources/memory_management_rules.dart:1773:    'avoid_retaining_disposed_widgets',
grep -n "AvoidRetainingDisposedWidgetsRule" lib/saropa_lints.dart
# lib/saropa_lints.dart:2573:  AvoidRetainingDisposedWidgetsRule.new,
```

**Rule class:** `AvoidRetainingDisposedWidgetsRule`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints` (message prefix `[avoid_retaining_disposed_widgets]`)

---

## Reproducer

Standalone, compiles with the Flutter SDK. Real code: `lib/components/primitive/menu/common_popup_menu_stagger.dart:164-168` in the Saropa contacts app.

```dart
import 'package:flutter/material.dart';

class StaggeredEntry extends PopupMenuEntry<dynamic> {
  const StaggeredEntry({super.key, required this.original, required this.animatedChild});

  final PopupMenuEntry<dynamic> original;
  final Widget animatedChild; // LINT (line 168 col 3) — but should NOT lint: this class IS a Widget

  @override
  double get height => original.height;

  @override
  bool represents(dynamic value) => original.represents(value);

  @override
  State<StaggeredEntry> createState() => _StaggeredEntryState();
}

class _StaggeredEntryState extends State<StaggeredEntry> {
  @override
  Widget build(BuildContext context) => widget.animatedChild;
}
```

**Frequency:** Always, for any Widget subclass whose direct superclass is not in the list (`PopupMenuEntry`, `ImplicitlyAnimatedWidget`, `ProxyWidget`, `SingleChildRenderObjectWidget`, `PreferredSize`-style custom bases, project base widgets).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the enclosing class is a Widget (transitively) |
| **Actual** | `[avoid_retaining_disposed_widgets] Non-widget class stores a reference to a Widget or State object...` at line 168, col 3 |

---

## AST Context

```
ClassDeclaration (_StaggeredPopupMenuEntry)   extends PopupMenuEntry<dynamic>
  └─ FieldDeclaration  ← node reported here
      └─ VariableDeclarationList (final Widget animatedChild)
```

---

## Root Cause

- `memory_management_rules.dart:1804` visits each `ClassDeclaration`.
- `memory_management_rules.dart:1821` skips the class only when `_isWidgetClass(node)` is true.
- `_isWidgetClass` (line 1878-1883) reads `node.extendsClause?.superclass.name.lexeme` and checks `_widgetBaseClasses.contains(...)` (list at line 1800).
- `PopupMenuEntry` is not in the list, so the class is classed as non-widget, and the field of type `Widget` (matched at line 1873 by `_isWidgetRelatedType`) is reported.
- The check is name-based on one level only. The resolved element supertype chain is never inspected, although the rule already uses resolved types for the field (line 1873).

---

## Why the code is correct

A `Widget` is immutable configuration that lives as long as the parent's build output. A widget holding a child widget is the normal composition pattern (`Padding.child`, `Container.child`). The leak the rule targets (a service or singleton holding a `State` or `Widget`) does not exist here.

---

## Affected project locations

- `lib/components/primitive/menu/common_popup_menu_stagger.dart:168` (`animatedChild`). The sibling field `original` on line 167 has type `PopupMenuEntry<dynamic>` and was not reported.

---

## Suggested Fix

In `_isWidgetClass`, when the class element is resolved, walk `node.declaredFragment?.element.allSupertypes` and return true if any supertype is a Flutter SDK `Widget`, `State` or `Element` (reuse `isFlutterSdkInterface`). Keep the name list as the fallback for unresolved ASTs.

---

## Fixture Gap

The fixture should include:

1. Class extending `PopupMenuEntry<dynamic>` with a `Widget` field. Expect NO lint.
2. Class extending `ImplicitlyAnimatedWidget` with a `Widget` field. Expect NO lint.
3. Plain class (no Flutter base) with a `Widget` field. Expect LINT.
4. Plain service class with a `State` field. Expect LINT.

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: Saropa contacts app, `lib/components/primitive/menu/common_popup_menu_stagger.dart`

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
