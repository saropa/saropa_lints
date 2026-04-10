# Bug: `prefer_const_widgets_in_lists` false positive on non-Widget lists and implicitly const declarations

## Summary

`prefer_const_widgets_in_lists` fires a false positive on `List<Color>` (and
potentially any `List<T>` where `T` is not a `Widget`) when the list contains
`InstanceCreationExpression` elements with const-compatible arguments. It also
fails to recognize implicitly const lists — those declared in `static const`
fields — where the list is already const by definition.

## Severity

**False positive** (INFO severity) — flags a `static const List<Color>` as
needing a `const` keyword, even though (a) it is not a widget list and (b) it
is already const.

## Reproduction

```dart
import 'package:flutter/material.dart';

extension SuperheroRatingValues on SuperheroRating {
  // FALSE POSITIVE: fires prefer_const_widgets_in_lists on lines 5-11
  static const List<Color> marvelColors = <Color>[
    Color(0xFF000000),
    Color(0xFF8A2BE2),
    Color(0xFFFFD700),
    Color(0xFF00FF00),
    Color(0xFF0000FF),
    Color(0xFFCC33FF),
    Color(0xFFFF0000),
  ];
}
```

**Expected**: No lint — `Color` is not a `Widget`, and the list is already
`static const`.

**Actual**: INFO: `[prefer_const_widgets_in_lists] Widget list recreated on
every rebuild. If elements are constant, the entire list can be const.`

The diagnostic message is doubly wrong:

1. This is not a widget list — it is a `List<Color>`.
2. The list is already `const` (declared `static const`), so it is not
   "recreated on every rebuild."

## Root cause

`PreferConstWidgetsInListsRule` in `widget_layout_rules.dart` line 1366.

Two independent bugs contribute to the false positive:

### 1. No type check on list element type — treats any `InstanceCreationExpression` as a widget

Lines 1391-1406 iterate list elements and set `hasWidgets = true` for any
`InstanceCreationExpression`:

```dart
for (final CollectionElement element in node.elements) {
  if (element is InstanceCreationExpression) {
    hasWidgets = true;  // BUG: Color is not a Widget
    if (element.keyword?.type != Keyword.CONST) {
      if (!_couldBeConst(element)) {
        allPotentiallyConst = false;
        break;
      }
    }
  } else if (element is! SpreadElement) {
    allPotentiallyConst = false;
    break;
  }
}
```

`Color(0xFF000000)` is an `InstanceCreationExpression`, so it passes the check
and sets `hasWidgets = true`. The rule never verifies that the constructed type
is actually a `Widget` subclass.

This affects any non-widget class with a const constructor:

- `Color(0xFF...)` — most common false positive
- `Offset(0, 0)`
- `Size(100, 200)`
- `EdgeInsets.all(8)`
- `BorderRadius.circular(4)`
- `BoxShadow(...)` with const-compatible args
- `Rect.fromLTWH(0, 0, 100, 100)`
- Any user-defined class with a const constructor and literal arguments

### 2. No check for implicitly const lists in `static const` / `const` declarations

Line 1385 checks `node.constKeyword != null` to skip already-const lists:

```dart
if (node.constKeyword != null) return;
```

This only catches explicitly const list literals like `const <Widget>[...]`.
When a list is part of a `static const` or `const` variable declaration, the
`const` keyword is on the `VariableDeclaration` (or `VariableDeclarationList`),
not on the `ListLiteral` node itself. Dart makes the list implicitly const in
this context, but the AST `constKeyword` on the `ListLiteral` is `null`.

AST structure for `static const List<Color> marvelColors = <Color>[...]`:

```
FieldDeclaration
  └─ VariableDeclarationList
       ├─ keyword: const          ← const is here
       └─ VariableDeclaration
            ├─ name: marvelColors
            └─ initializer: ListLiteral
                 ├─ constKeyword: null  ← rule checks here, finds null
                 └─ elements: [InstanceCreationExpression, ...]
```

The rule sees `constKeyword == null` on the `ListLiteral` and proceeds to flag
it, even though the list is already const via its parent declaration.

## `_couldBeConst` analysis — why `Color` passes

The helper at line 1414 checks if constructor arguments are const-compatible:

```dart
bool _couldBeConst(InstanceCreationExpression node) {
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression) {
      if (!_isConstExpression(arg.expression)) return false;
    } else if (!_isConstExpression(arg)) {
      return false;
    }
  }

  return true;
}
```

`_isConstExpression` (line 1426) returns `true` for `IntegerLiteral`. Since
`Color(0xFF000000)` has a single `IntegerLiteral` argument, `_couldBeConst`
returns `true`. Combined with bug #1 (no widget type check), the rule
incorrectly concludes this is a widget list that should be const.

## Suggested fix

### Fix 1: Check that list elements are actually Widget subclasses

Before setting `hasWidgets = true`, verify the constructed type extends
`Widget`:

```dart
if (element is InstanceCreationExpression) {
  final DartType? type = element.staticType;
  if (type == null) continue;

  // Only flag actual Widget lists
  final bool isWidget = _isWidgetType(type);
  if (!isWidget) {
    // Non-widget InstanceCreationExpression — skip entirely.
    // This is a Color, Offset, EdgeInsets, etc.
    continue;
  }

  hasWidgets = true;
  // ... existing const check ...
}
```

Where `_isWidgetType` checks the type hierarchy:

```dart
bool _isWidgetType(DartType type) {
  if (type is! InterfaceType) return false;
  // Walk the supertype chain looking for Widget
  for (InterfaceType? t = type; t != null;) {
    if (t.element.name == 'Widget' &&
        t.element.library.identifier.startsWith('package:flutter/')) {
      return true;
    }
    t = t.element.supertype;
  }

  return false;
}
```

Alternatively, check the list's type argument directly:

```dart
final TypeAnnotation? typeArg = node.typeArguments?.arguments.firstOrNull;
if (typeArg != null) {
  final DartType? listElementType = typeArg.type;
  if (listElementType != null && !_isWidgetType(listElementType)) {
    return; // Not a widget list, skip
  }
}
```

### Fix 2: Check for implicitly const lists

Before the `constKeyword` check, also check if the list is inside a `const`
variable declaration:

```dart
// Skip if already const (explicit)
if (node.constKeyword != null) return;

// Skip if implicitly const (inside a const variable declaration)
if (_isInConstContext(node)) return;
```

```dart
bool _isInConstContext(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is VariableDeclaration) {
      final AstNode? declList = current.parent;
      if (declList is VariableDeclarationList) {
        if (declList.keyword?.type == Keyword.CONST) return true;
      }
      break;
    }
    if (current is DefaultFormalParameter ||
        current is ConstructorFieldInitializer) {
      // Also implicitly const in default parameter values
      // and const constructor field initializers
      break;
    }
    current = current.parent;
  }

  return false;
}
```

### Both fixes should be applied

Fix 1 addresses the fundamental bug (wrong type detection). Fix 2 addresses
the secondary bug (flagging already-const lists). Both are independent and
should be applied together for correctness.

## Test cases to add

```dart
// Should NOT trigger — List<Color>, not List<Widget>
class GoodNonWidgetList {
  static const List<Color> colors = <Color>[
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ];
}

// Should NOT trigger — List<Offset>, not List<Widget>
class GoodOffsetList {
  static const List<Offset> offsets = <Offset>[
    Offset(0, 0),
    Offset(1, 1),
  ];
}

// Should NOT trigger — implicitly const via static const
class GoodImplicitlyConstWidgetList {
  static const List<Widget> items = <Widget>[
    SizedBox.shrink(),
    SizedBox.expand(),
  ];
}

// Should NOT trigger — implicitly const via const field
class GoodConstField {
  const GoodConstField();
  final List<Widget> items = const <Widget>[
    SizedBox.shrink(),
  ];
}

// SHOULD trigger — non-const list of widgets with const-compatible elements
// in a non-const context (e.g. inside build())
class BadNonConstWidgetList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // expect_lint: prefer_const_widgets_in_lists
    final List<Widget> items = <Widget>[
      Text('a'),
      Text('b'),
    ];
    return Column(children: items);
  }
}

// Should NOT trigger — elements use non-const expressions
class GoodNonConstElements extends StatelessWidget {
  final String label;
  const GoodNonConstElements({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[
      Text(label), // label is not const
    ];
    return Column(children: items);
  }
}

// Should NOT trigger — List<BoxShadow>, not List<Widget>
class GoodBoxShadowList {
  static const List<BoxShadow> shadows = <BoxShadow>[
    BoxShadow(color: Color(0x42000000), blurRadius: 4),
  ];
}

// Should NOT trigger — List<EdgeInsets>, not List<Widget>
class GoodEdgeInsetsList {
  static const List<EdgeInsets> paddings = <EdgeInsets>[
    EdgeInsets.all(8),
    EdgeInsets.all(16),
  ];
}
```

## Affected code in `contacts` project

The false positive fires on `superhero_gradient_scheme.dart` line 185 for
`marvelColors`. The same file contains 12 other `static const List<Color>`
fields that may also be affected (they use the same pattern):

- `_StrengthColorsLight` (line 53)
- `_SpeedColorsLight` (line 63)
- `_PowerColorsLight` (line 73)
- `_IntelligenceColorsLight` (line 83)
- `_DurabilityColorsLight` (line 93)
- `_CombatColorsLight` (line 103)
- `_StrengthColors` (line 112)
- `_SpeedColors` (line 122)
- `_PowerColors` (line 132)
- `_IntelligenceColors` (line 142)
- `_DurabilityColors` (line 152)
- `_CombatColors` (line 162)
- `dcColors` (line 170)
- `marvelColors` (line 185) — reported instance

Any other `static const List<T>` where `T` has a const constructor and
elements use literal arguments will also be affected.

## File references

- Rule: `lib/src/rules/widget_layout_rules.dart` line 1366
- `addListLiteral` callback: `lib/src/rules/widget_layout_rules.dart` line 1383
- `hasWidgets` check (missing type guard): `lib/src/rules/widget_layout_rules.dart` line 1393
- `constKeyword` check (misses implicit const): `lib/src/rules/widget_layout_rules.dart` line 1385
- `_couldBeConst`: `lib/src/rules/widget_layout_rules.dart` line 1414
- `_isConstExpression`: `lib/src/rules/widget_layout_rules.dart` line 1426
