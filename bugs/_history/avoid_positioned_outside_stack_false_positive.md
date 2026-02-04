# Bug: `avoid_positioned_outside_stack` false positive in builder callbacks

## Summary

`avoid_positioned_outside_stack` fires a false positive when `Positioned` is
returned from a named-parameter callback (e.g. `BlocBuilder.builder`,
`StreamBuilder.builder`, `Builder.builder`) inside a `build()` method, even
when the widget is correctly placed inside a `Stack` at the call site.

## Severity

**False positive** (ERROR severity) -- causes developers to restructure
valid code or add `// ignore` comments to silence a warning that does not
represent a real bug.

## Reproduction

```dart
// --- widget file ---
class SearchContactAvatar extends StatelessWidget {
  const SearchContactAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyCubit, MyState>(
      builder: (BuildContext context, MyState state) {
        if (state.isEmpty) return const SizedBox.shrink();

        // FALSE POSITIVE: fires avoid_positioned_outside_stack here
        return Positioned(
          right: 50,
          bottom: 15,
          child: Text('Hello'),
        );
      },
    );
  }
}

// --- call site (valid usage) ---
// Indexer extends Stack, so Positioned is correctly parented.
Indexer(
  children: <Widget>[
    Indexed(index: 100, child: SearchContactAvatar()),
    otherContent,
  ],
)
```

**Expected**: No lint (or `indeterminate` -- cannot determine parent from
static analysis alone).

**Actual**: ERROR: `Positioned widget used outside of a Stack.`

## Root cause

`_findWidgetAncestor` in `widget_layout_rules.dart` (line ~6821).

Two issues in the AST walk contribute to the false positive:

### 1. `FunctionExpression` check only handles positional args in method calls

Lines 6856-6867 check for `FunctionExpression` inside `.generate()` / `.map()`
and correctly return `indeterminate`. But the check requires:

```
FunctionExpression → parent: ArgumentList → parent: MethodInvocation
```

For named-parameter builder callbacks the AST structure is:

```
FunctionExpression → parent: NamedExpression → parent: ArgumentList → parent: InstanceCreationExpression
```

Since `feParent` is `NamedExpression` (not `ArgumentList`), the check is
skipped entirely. The walk continues upward through the callback boundary.

### 2. Builder widgets incorrectly set `passedThroughWidget`

After passing through the `FunctionExpression` unchecked, the walk reaches
`BlocBuilder`'s `InstanceCreationExpression` (line 6870). Since `BlocBuilder`
is not `Stack`/`IndexedStack` and does not extend `Stack`, the walk sets
`passedThroughWidget = true` (line 6882).

When the walk then reaches the `build()` `MethodDeclaration` (line 6886),
the `passedThroughWidget` flag prevents the `indeterminate` return
(line 6894-6896). The walk breaks and falls through to return `notFound`
(line 6905), which triggers the lint.

The flag's logic assumes: "an intermediate widget constructor exists between
`Positioned` and `build()`, so `Positioned` is nested inside another widget
and we can determine it's misplaced." But builder-pattern widgets
(`BlocBuilder`, `StreamBuilder`, `Builder`, `AnimatedBuilder`, etc.) are
transparent wrappers -- the widget returned by their callback IS the
effective child in the render tree, and its valid parent depends on the
call site, not the builder widget itself.

## AST walk trace

```
Positioned(...)                           -- start node
  ↑ ReturnStatement                       -- line 6840: in build(), skip
  ↑ Block
  ↑ BlockFunctionBody
  ↑ FunctionExpression                    -- line 6856: parent is NamedExpression, NOT ArgumentList → SKIPPED
  ↑ NamedExpression (builder:)
  ↑ ArgumentList
  ↑ InstanceCreationExpression (BlocBuilder) -- line 6870: not Stack → passedThroughWidget = true
  ↑ ReturnStatement                       -- line 6840: in build(), skip
  ↑ Block (try body)
  ↑ TryStatement
  ↑ Block (build body)
  ↑ BlockFunctionBody
  ↑ MethodDeclaration (build)             -- line 6886: passedThroughWidget=true → break
→ returns notFound                        -- triggers lint (false positive)
```

## Suggested fix

Extend the `FunctionExpression` boundary check to handle named-parameter
callbacks in widget constructors:

```dart
// Lines 6856-6867: current check
if (current is FunctionExpression) {
  final feParent = current.parent;

  // NEW: Handle named-parameter callbacks (e.g., builder: (ctx) => ...)
  // The callback output's placement depends on the call site, not this widget.
  if (feParent is NamedExpression) {
    return _AncestorResult.indeterminate;
  }

  // EXISTING: Handle positional args in .generate() / .map()
  if (feParent is ArgumentList) {
    final grandparent = feParent.parent;
    if (grandparent is MethodInvocation) {
      final name = grandparent.methodName.name;
      if (name == 'generate' || name == 'map') {
        return _AncestorResult.indeterminate;
      }
    }
  }
}
```

This returns `indeterminate` for any callback passed as a named parameter,
since static analysis cannot determine the runtime widget tree parent.

### Narrower alternative

If the broad `NamedExpression` check risks false negatives, restrict it to
known builder-pattern parameter names:

```dart
if (feParent is NamedExpression) {
  final String paramName = feParent.name.label.name;
  const Set<String> builderParams = <String>{
    'builder', 'itemBuilder', 'separatorBuilder',
    'layoutBuilder', 'transitionBuilder',
  };
  if (builderParams.contains(paramName)) {
    return _AncestorResult.indeterminate;
  }
}
```

## Test cases to add

```dart
// Should NOT trigger (indeterminate -- depends on call site)
class _PositionedInBlocBuilder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyCubit, MyState>(
      builder: (context, state) {
        return Positioned(top: 10, child: Text('x'));
      },
    );
  }
}

// Should NOT trigger (indeterminate -- depends on call site)
class _PositionedInStreamBuilder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.value(1),
      builder: (context, snapshot) {
        return Positioned(top: 10, child: Text('x'));
      },
    );
  }
}

// Should NOT trigger (indeterminate -- arrow function variant)
class _PositionedInBuilderArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Positioned(top: 10, child: Text('x')),
    );
  }
}

// SHOULD still trigger -- Positioned inside Column inside builder
class _PositionedInColumnInsideBuilder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyCubit, MyState>(
      builder: (context, state) {
        // expect_lint: avoid_positioned_outside_stack
        return Column(children: [Positioned(top: 10, child: Text('x'))]);
      },
    );
  }
}
```

## Affected rules

`_findWidgetAncestor` is shared by multiple rules. The same false-positive
pattern may affect:

- `avoid_table_cell_outside_table`
- `avoid_spacer_in_wrap`
- `avoid_flex_child_outside_flex`
- Any rule using `_findWidgetAncestor` with builder-pattern widgets

## Workaround

Move `Positioned` to the call site where the `Stack`/`Indexer` parent is
visible in the same AST scope:

```dart
Indexer(
  children: <Widget>[
    Indexed(
      index: 100,
      child: Positioned(
        right: 50,
        bottom: 15,
        child: SearchContactAvatar(), // returns avatar content only
      ),
    ),
  ],
)
```

## File references

- Rule: `lib/src/rules/widget_layout_rules.dart` line 7005
- Helper: `lib/src/rules/widget_layout_rules.dart` line 6821
- Fixture: `example/lib/widgets/layout_crash_rules_fixture.dart` line 22
