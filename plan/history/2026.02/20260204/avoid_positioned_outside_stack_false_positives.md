# False positive: avoid_positioned_outside_stack for cross-boundary and variable-assigned Positioned widgets

## Rule

`avoid_positioned_outside_stack` in `AvoidPositionedOutsideStackRule`
(`lib/src/rules/widget_layout_rules.dart`)

## Problem

The rule fires on `Positioned` widgets that are correctly placed inside a
`Stack` at runtime, producing false positives in two categories:

### Category 1: Widget whose build() returns Positioned

When a `StatelessWidget` or `State.build()` returns a `Positioned` as the root
widget, the rule cannot see that the widget is placed inside a `Stack` at the
call site. Since the widget class itself does not create a render object, the
`Positioned` ends up correctly parented to the caller's `Stack` at runtime.

### Category 2: Positioned assigned to a local variable

When `Positioned` is assigned via `AssignmentExpression` (not
`VariableDeclaration`) to a variable that is later used inside a `Stack` in the
same `build()` method, the rule flags it because `AssignmentExpression` was not
treated as an indeterminate boundary.

## Reproduction

### Category 1 — Widget returning Positioned from build

```dart
// Widget designed to be placed inside a Stack
class SearchBackgroundImage extends StatelessWidget {
  const SearchBackgroundImage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(      // <-- false positive
      top: -75,
      right: -300,
      child: SizedBox(width: 500, height: 500),
    );
  }
}

// Caller correctly places it in a Stack
Stack(
  children: [
    const SearchBackgroundImage(),  // Works fine at runtime
    // ...
  ],
)
```

### Category 2 — Assignment then Stack usage

```dart
Widget build(BuildContext context) {
  final Widget? countWidget;
  if (showCount) {
    countWidget = Positioned(       // <-- false positive
      bottom: -3,
      right: -3,
      child: CountBadge(count: count),
    );
  } else {
    countWidget = null;
  }

  if (countWidget != null) {
    return Stack(
      children: [iconWidget, countWidget],  // Used correctly in Stack
    );
  }

  return iconWidget;
}
```

## Affected files in saropa contacts app

| File                              | Line | Category                                                                 |
| --------------------------------- | ---- | ------------------------------------------------------------------------ |
| `common_pinch_scale_gesture.dart` | 274  | 1 (build returns Positioned.fill, used via OverlayEntry)                 |
| `common_header_bar.dart`          | 465  | 1 (BottomRightIcons.build returns Positioned, used in Stack at line 319) |
| `common_icon.dart`                | 240  | 2 (assigned to countWidget, used in Stack at line 316)                   |
| `search_background_image.dart`    | 34   | 1 (build returns Positioned, used in Stack in app_search_bar.dart:190)   |
| `search_contact_avatar.dart`      | 40   | 1 (build returns Positioned, used in Indexer — a Stack subclass)         |

## Root cause

Two gaps in `_findWidgetAncestor`:

1. **`AssignmentExpression` not treated as indeterminate**: The function checks
   `VariableDeclaration` (initial `final x = ...`) but not
   `AssignmentExpression` (subsequent `x = ...`). When `Positioned` is assigned
   via `=` to an already-declared variable, the walk continues past the
   assignment up to the `build()` boundary and returns `notFound`.

2. **`build()` boundary always returns `notFound`**: When the AST walk reaches
   the enclosing `build()` method without finding a `Stack` ancestor AND without
   passing through any intermediate widget constructor, the `Positioned` is the
   root widget of that `build()` method. Its eventual parent depends entirely on
   how the caller places this widget. The rule cannot determine correctness from
   the AST alone, so it should return `indeterminate` instead of `notFound`.

## Fix

Two changes to `_findWidgetAncestor`:

### 1. Add AssignmentExpression check

```dart
// Stop at assignments -- can't track where the variable ends up.
if (current is AssignmentExpression) return _AncestorResult.indeterminate;
```

### 2. Track intermediate widget constructors at build() boundary

```dart
bool passedThroughWidget = false;

// ... in the InstanceCreationExpression block, after existing checks:
passedThroughWidget = true;

// ... at the build() method boundary:
if (current is MethodDeclaration) {
  if (current.name.lexeme != 'build') {
    return _AncestorResult.indeterminate;
  }

  if (!passedThroughWidget) {
    return _AncestorResult.indeterminate;
  }
  break;
}
```

When `passedThroughWidget` is false at the `build()` boundary, `Positioned` is
the root widget — return `indeterminate`. When true, an intermediate widget
(like `Column`) was found between `Positioned` and `build()`, so the original
`notFound` error is still correct.

## Impact on other callers

`_findWidgetAncestor` is shared by 5 rules. Impact analysis:

| Rule                                | Result used              | Impact                                               |
| ----------------------------------- | ------------------------ | ---------------------------------------------------- |
| `avoid_table_cell_outside_table`    | `found`, `indeterminate` | Benefits from same fix (same false positive pattern) |
| `avoid_positioned_outside_stack`    | `found`, `indeterminate` | Fixed                                                |
| `avoid_spacer_in_wrap`              | `wrongParent` only       | Unaffected                                           |
| `avoid_scrollable_in_intrinsic`     | `found` only             | Unaffected                                           |
| `avoid_unconstrained_dialog_column` | `found` only             | Unaffected                                           |

## Remaining false negative

A `Positioned` assigned to a variable and then placed in a non-Stack widget
(e.g. `Column`) will not be caught because the assignment returns
`indeterminate`. This is an inherent limitation of single-pass AST analysis
without data flow tracking, and is consistent with how `VariableDeclaration` is
already handled.
