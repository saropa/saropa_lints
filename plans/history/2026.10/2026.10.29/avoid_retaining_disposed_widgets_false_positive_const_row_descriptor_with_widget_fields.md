# BUG: `avoid_retaining_disposed_widgets` — flags `Widget` fields on an immutable `const` row-descriptor class that is consumed in `build`

**Status: Open**

Created: 2026-10-29
Rule: `avoid_retaining_disposed_widgets`
File: `lib/src/rules/resources/memory_management_rules.dart` (line ~1753; class check 1819-1856)
Severity: False positive
Rule version: v2 | Since: v4.14.0 | Updated: 17.0.1-beta.2

---

## Summary

A plain class with a `const` constructor and only `final` fields describes one row of a list (`title`, `leading` widget, `trailing` widget, `body` widget). A `StatelessWidget` receives a `List` of them and turns each into a tile inside `build`. The descriptors are created in the parent's `build` and die with the parent's frame. Nothing is stored in a service, controller, singleton or `State` field, so no widget outlives its tree. The rule reports each `Widget` field.

---

## Attribution Evidence

```bash
grep -rn "'avoid_retaining_disposed_widgets'" lib/src/rules/
# lib/src/rules/resources/memory_management_rules.dart:1773:    'avoid_retaining_disposed_widgets',
```

**Rule class:** `AvoidRetainingDisposedWidgetsRule` (`memory_management_rules.dart:1753`), registered in `lib/saropa_lints.dart:2573`
**Diagnostic as seen in Problems panel:** `[avoid_retaining_disposed_widgets] Non-widget class stores a reference to a Widget or State object...` at 50:3, 58:3, 61:3 (source: saropa_lints)

---

## Reproducer

Standalone (needs the Flutter SDK). Real code: `lib/components/system/about/about_tile_list.dart` lines 15-64 (`AboutTileData`) and 67-90 (`AboutTileList`) in the Saropa contacts app.

```dart
import 'package:flutter/material.dart';

class RowData {
  const RowData({this.title, this.leading, this.trailing, this.body});

  final String? title;
  final Widget? leading; // LINT — but should NOT lint
  final Widget? trailing; // LINT — but should NOT lint
  final Widget? body; // LINT — but should NOT lint
}

class RowList extends StatelessWidget {
  const RowList({required this.rows, super.key});

  final List<RowData> rows;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      for (final RowData row in rows)
        ListTile(title: Text(row.title ?? ''), leading: row.leading, trailing: row.trailing),
    ],
  );
}

void main() => runApp(
  const MaterialApp(
    home: Scaffold(body: RowList(rows: <RowData>[RowData(title: 'a', leading: Icon(Icons.add))])),
  ),
);
```

**Frequency:** Always for a non-widget class with `Widget` fields, regardless of constness.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic for an immutable value class (`const` constructor, all fields `final`) that is a widget-configuration descriptor |
| **Actual** | `[avoid_retaining_disposed_widgets]` at each `Widget` field (50:3, 58:3, 61:3) |

---

## AST Context

```
ClassDeclaration (RowData)                     ← _isWidgetClass(node) false: no extends clause
  ├─ ConstructorDeclaration (const RowData)
  └─ FieldDeclaration (final Widget? leading)  ← node reported here (reporter.atNode(member), line 1837)
```

---

## Root Cause

`context.addClassDeclaration` (`memory_management_rules.dart:1819`) skips only classes that extend a known widget base (`_isWidgetClass`, line 1878, using `_widgetBaseClasses`). For every other class it reports each field whose resolved type is `Widget`, `State`, `Element`, `RenderObject`, `BuildContext` or `List` of those (`_isWidgetRelatedType`, line 1862). It does not look at whether the class is immutable or whether it is held anywhere beyond the build that created it. The rule documentation names services, controllers and singletons as the leak risk; a `const` value class with `final` fields is the same composition pattern as `Widget child` on a widget.

---

## Why the code is correct

The descriptors are immutable and are not stored in any long-lived object. Their lifetime is one build. The widgets they hold are the widgets the parent just created for that frame.

---

## Suggested Fix

Exempt a class that has a `const` generative constructor and no non-`final` instance fields (an immutable value class), for `Widget`-typed fields only. Keep reporting `State`, `Element`, `RenderObject` and `BuildContext` fields in such classes, since retaining those is the real leak.

---

## Fixture Gap

1. `class Row { const Row({this.leading}); final Widget? leading; }` — expect NO lint after the fix.
2. `class Service { Widget? cached; }` — expect LINT (mutable, non-const).
3. `class Row { const Row(this.state); final State state; }` — expect LINT (`State` stays flagged).
4. `class Row { Row(this.leading); final Widget leading; }` (no const constructor) — decide: expect LINT.

---

## Environment

- saropa_lints version: 17.0.1-beta.2 (this file differs from the repo source only by an added import at line 10)
- Dart SDK version: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: Saropa contacts app, `lib/components/system/about/about_tile_list.dart` (50:3, 58:3, 61:3; 14 construction sites)

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
