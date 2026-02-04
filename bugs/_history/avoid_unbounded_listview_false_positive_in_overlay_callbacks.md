# False positive: avoid_unbounded_listview_in_column inside Autocomplete.optionsViewBuilder

## Rule

`avoid_unbounded_listview_in_column` in `AvoidUnboundedListviewInColumnRule`
(`lib/src/rules/widget_layout_rules.dart`)

## Problem

The rule walks up the AST parent chain from a `ListView` looking for a `Column`
ancestor. When a `ListView.builder` is used inside an
`Autocomplete.optionsViewBuilder` callback, the AST walk passes through the
callback's function expression, reaches the `Autocomplete` constructor argument,
and continues up to a `Column` that contains the `Autocomplete` widget.

The rule then reports a violation — but at runtime the `optionsViewBuilder`
content is rendered in an **Overlay**, not inside the parent `Column`. The
`ListView` never has unbounded constraints from the `Column` because it exists
in a completely separate render subtree.

## Reproduction

```dart
Column(
  children: [
    Autocomplete<MyModel>(
      optionsBuilder: (TextEditingValue value) => myOptions,
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<MyModel> onSelected,
        Iterable<MyModel> options,
      ) => Material(
        child: ListView.builder(         // <-- false positive here
          itemCount: options.length,
          itemBuilder: (BuildContext context, int index) {
            return ListTile(title: Text('$index'));
          },
        ),
      ),
    ),
  ],
)
```

**Lint fires** on the `ListView.builder`, but the `Material` + `ListView` is
rendered in an `Overlay` at runtime, not in the `Column`.

## Root cause

The ancestor walk (depth-limited to 20 nodes) does not account for callback
parameters that inject their return value into a different part of the widget
tree. It treats the AST parentage as equivalent to the runtime widget parentage,
which is incorrect for overlay-based APIs.

## Affected APIs (non-exhaustive)

Any widget whose builder callbacks render content in an overlay or separate
subtree:

- `Autocomplete.optionsViewBuilder`
- `SearchAnchor.suggestionsBuilder`
- `PopupMenuButton.itemBuilder`
- `DropdownButton.selectedItemBuilder`
- `showDialog` / `showModalBottomSheet` builder parameters

## Suggested fix

When walking up from a `ListView`, if the walk crosses a **function expression
boundary** that is a named parameter of a widget constructor, check whether that
parameter is known to render in an overlay. Options:

1. **Allowlist approach**: Maintain a set of `(WidgetType, parameterName)` pairs
   known to render in overlays (e.g. `Autocomplete.optionsViewBuilder`,
   `SearchAnchor.suggestionsBuilder`). Stop the walk if the function expression
   is an argument matching one of these pairs.

2. **Broader heuristic**: Stop the ancestor walk at any function expression that
   is a named argument ending in `Builder` or `builder` to a widget constructor.
   This is less precise but catches more cases with minimal false negatives,
   since `*builder` callbacks in Flutter commonly produce widgets rendered in
   separate subtrees or at least with their own constraints.

3. **Conservative**: Stop the walk at any function expression boundary that is a
   callback argument to a widget constructor. The rationale is that the callback
   return value's constraints are determined by the widget consuming it, not by
   the widget's own ancestors.

Option 3 is the most conservative and likely the most correct — a widget
constructor that receives a builder callback controls how and where that widget
is placed, so the Column ancestor of the constructor is irrelevant to the
constraints of the builder's return value.
