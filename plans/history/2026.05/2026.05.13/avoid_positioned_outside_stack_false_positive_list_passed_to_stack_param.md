# BUG: `avoid_positioned_outside_stack` — False positive when `Positioned` is passed via a `List<Widget>` parameter that the receiver spreads into a `Stack`

**Status: Fixed**

Created: 2026-05-13
Fixed: 2026-05-13
Rule: `avoid_positioned_outside_stack`
File: `lib/src/rules/widget/widget_layout_constraints_rules.dart` (line ~4953)
Severity: False positive
Rule version: v5 | Since: (unknown — present in current ruleset)

## Attribution (positive)

```text
$ grep -rn "'avoid_positioned_outside_stack'" D:/src/saropa_lints/lib/src/rules/
D:/src/saropa_lints/lib/src/rules/widget/widget_layout_constraints_rules.dart:4953:    'avoid_positioned_outside_stack',
```

Confirmed: the rule lives in `saropa_lints`.

## Reproducer

A consumer widget accepts a `List<Widget>` parameter (e.g. `backgroundLayers`) and spreads it into its own `Stack`. Callers populate that list with `Positioned` widgets — the runtime parent IS a `Stack`, but the static analyzer's ancestor walk can't see through the parameter into the consumer.

### Consumer widget (correct at runtime)

```dart
class FocusCard extends StatelessWidget {
  const FocusCard({
    required this.child,
    this.backgroundLayers = const <Widget>[],
    super.key,
  });

  /// Optional Positioned/Stack children rendered behind the card content.
  final List<Widget> backgroundLayers;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      // ...decoration...
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          // Background layers first so they sit behind the content.
          ...backgroundLayers,
          // ...other Positioned children...
          child,
        ],
      ),
    );
  }
}
```

### Call site (lints fire here)

```dart
return FocusCard(
  // ...
  backgroundLayers: <Widget>[
    // [avoid_positioned_outside_stack] Positioned widget used outside of a Stack.
    Positioned(
      right: -16,
      bottom: -16,
      child: IgnorePointer(child: CommonIcon(/* ... */)),
    ),
  ],
  child: /* ... */,
);
```

## Expected behavior

`Positioned` widgets supplied to a `List<Widget>` parameter that is documented as "rendered inside a Stack" (or whose receiver visibly spreads the list into a `Stack`) should not trigger the lint. The runtime parent is well-defined and correct.

## Actual behavior

The lint fires on the `Positioned` constructor at the call site because the ancestor walk encounters the `List<Widget>` literal / named argument `backgroundLayers:` and can't resolve where that list ends up at runtime.

## Root cause hypothesis

Per the `CHANGELOG_ARCHIVE.md` history (entries 3100 and 3121), `_findWidgetAncestor` already treats:

- named-parameter **callbacks** (`BlocBuilder.builder`, `StreamBuilder.builder`, `LayoutBuilder.builder`, ...) as indeterminate boundaries
- `AssignmentExpression` as an indeterminate boundary

But it doesn't treat **`List<Widget>` literals passed to a named parameter** as indeterminate. When `Positioned` is an element of such a list, the visible ancestor chain ends at the list literal / the `NamedExpression`, never reaching a `Stack`. The current logic appears to require the `Stack` to be a direct widget-tree ancestor in the AST, which fails the moment the widget is hoisted into a list passed across a widget boundary.

## Fixture gap

There is no fixture in the existing FP test groups for:

- `Positioned` as a child of a `List<Widget>` literal passed as a named argument to a custom widget that internally spreads the list into a `Stack`

This pattern is common in the project (the `FocusCard` widget uses `backgroundLayers` for watermarks, gradient orbs, accent bars, etc.) and is the canonical way to compose stack overlays without leaking `Stack` into every consumer.

## Suggested fix

Extend `_findWidgetAncestor` so a `ListLiteral` whose `staticType` is `List<Widget>` (or `List<T>` where `T` is a supertype that can contain widgets) is treated as an indeterminate boundary when it appears inside a `NamedExpression`. This matches the existing treatment of builder callbacks: when the ancestor walk hits a boundary it can't statically resolve, it returns "unknown" instead of "not inside a Stack".

The boundary should not return "is inside a Stack" — only "indeterminate". This keeps the rule effective for the genuinely broken case of `Positioned` placed in a `Column`/`Row`/`Wrap`/etc.

## Downstream impact / context

Affected call sites in `D:/src/contacts`:

- `lib/components/event/special_events/daily_notice_focus_card.dart:157` — `Positioned` watermark in the `backgroundLayers` list passed to `FocusCard`.
- Likely the same pattern appears in `today_focus_card.dart` if it also uses `FocusCard.backgroundLayers`.

Downstream is suppressing these via `// ignore: avoid_positioned_outside_stack` with a comment pointing at this bug file.

## Resolution

Added a `treatCustomWidgetParentAsIndeterminate` mode to the shared `_findWidgetAncestor` helper in `lib/src/rules/widget/widget_layout_constraints_rules.dart`, and opted `avoid_positioned_outside_stack` into it. When walking up the AST, the *first* `InstanceCreationExpression` encountered is now classified via a new `_isCustomFlutterWidget` helper:

- If the IC's static type is declared in `package:flutter/`, `dart:`, or `flutter_mocks.dart` (the local test stub), it is treated as a Flutter framework widget — the walk continues as before. `Column(children: [Positioned(...)])` still lints because `Column` is framework-owned.
- If the IC's static type is a `Widget` declared anywhere else (any user-defined widget such as `FocusCard`), the walker returns `_AncestorResult.indeterminate`. The custom widget could spread `child` / `children` into a hidden `Stack`, `IndexedStack`, or `Wrap` inside its own `build()` — invisible to static analysis.

The check is gated on `!passedThroughWidget`, so only the direct widget consumer of the `Positioned` flips the result to indeterminate. Grandparent ICs further up the chain (which do not change the child relationship) still behave as before. The `checkSuperTypes` matching for `Stack`/`IndexedStack` runs *before* the custom-widget check, so `Indexer` (which extends `Stack` from `package:indexed`) is still detected as `found`.

Fixture coverage added in `example/lib/widgets/layout_crash_rules_fixture.dart`:

- `testPositionedInCustomWidgetBackgroundLayersIndeterminate` — `_FocusCard(backgroundLayers: [Positioned(...)])`, no lint.
- `testPositionedInCustomWidgetChildIndeterminate` — `_FocusCard(child: Positioned(...))`, no lint.

The existing `testPositionedBad` (`Column(children: [Positioned(...)])`) continues to lint, since `Column` is mocked under the `flutter_mocks.dart` library that the resolver treats as framework.
