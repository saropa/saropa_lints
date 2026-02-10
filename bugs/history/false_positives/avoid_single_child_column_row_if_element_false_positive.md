# Bug: `avoid_single_child_column_row` false positive on `IfElement` and `ForElement` in collection literals

## Summary

The `avoid_single_child_column_row` rule incorrectly flags Column/Row widgets
whose `children` list contains a single `IfElement` (collection `if`/`else`) or
`ForElement` (collection `for`). These Dart collection control-flow elements can
produce varying numbers of children at runtime, but the rule treats them as
opaque single elements and reports the Column/Row as having only one child.

The rule already handles top-level `SpreadElement` correctly (skipping when
spreads are present), but `IfElement` and `ForElement` are equally dynamic and
receive no special treatment.

## Severity

**False positive** -- produces noise on idiomatic Dart collection-if and
collection-for patterns. These are the standard way to build conditional or
repeated widget lists in Flutter and flagging them will cause developers to
either suppress the rule or ignore it entirely.

## Reproduction

### Minimal example (IfElement with spread in else branch)

```dart
Column(
  children: <Widget>[
    if (items == null)
      const Text('No items')
    else
      ...items.map((String s) => Text(s)),
    //  ^^^ spread inside IfElement — can produce many children
  ],
)
// FLAGGED: avoid_single_child_column_row (INFO)
```

### Minimal example (IfElement without else — conditional child)

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: <Widget>[
    if (showHeader) const Text('Header'),
    // At runtime: 0 or 1 children. But also means Column could have 0 children,
    // so refactoring to a direct child is not equivalent.
  ],
)
// FLAGGED: avoid_single_child_column_row (INFO)
```

### Minimal example (ForElement — loop producing multiple children)

```dart
Column(
  children: <Widget>[
    for (final String item in items) Text(item),
    // At runtime: 0, 1, or many children depending on items.length
  ],
)
// FLAGGED: avoid_single_child_column_row (INFO)
```

### Minimal example (IfElement with multiple children per branch)

```dart
Row(
  children: <Widget>[
    if (isLoggedIn)
      ...userMenuItems
    else
      ...guestMenuItems,
  ],
)
// FLAGGED: avoid_single_child_column_row (INFO)
```

### Lint output

```
line:col • [avoid_single_child_column_row] Column/Row with single child is
unnecessary. • avoid_single_child_column_row • INFO
```

## Real-world occurrence

Found in `saropa/lib/components/activity/timeline_activity_day_list.dart` at
line 147:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  spacing: ThemeCommonSpace.Medium.size,
  children: <Widget>[
    if (sequentialGroup == null || sequentialGroup.isListNullOrEmpty)
      const NoActivitiesNotice()
    else
      ...sequentialGroup.map(
        (ActivityContactGrouped group) => ActivityViewWidget(
          group.activity,
          count: group.count,
          showContact: true,
          showDate: false,
          showTime: widget.showTime,
          showTimeAgo: widget.showTime,
          showTimeSeconds: widget.showTimeSeconds,
          showKebabMenu: false,
        ),
      ),
  ],
).withPaddingLeft(ThemeCommonSpace.Large),
```

This Column shows either a single `NoActivitiesNotice` widget (empty state) or
a spread of N `ActivityViewWidget` instances (one per activity group). The
`crossAxisAlignment` and `spacing` properties are meaningful when multiple
activity widgets are rendered. Refactoring this to remove the Column is not
feasible.

## Root cause

**File:** `lib/src/rules/widget_layout_rules.dart`, lines 383–441
(`AvoidSingleChildColumnRowRule`)

The rule iterates over the top-level `CollectionElement` nodes in the `children`
`ListLiteral` and classifies each as either a `SpreadElement` or a non-spread
element:

```dart
for (final CollectionElement element in value.elements) {
  if (element is SpreadElement) {
    hasSpread = true;
  } else {
    nonSpreadCount++;
  }
}

// Only report if: single non-spread element AND no spreads
if (nonSpreadCount == 1 && !hasSpread) {
  reporter.atNode(node.constructorName, code);
}
```

The problem is that the `else` branch lumps all non-spread `CollectionElement`
types together as single static children. In the Dart analyzer AST, collection
literals can contain these `CollectionElement` subtypes:

| AST node type     | Can produce multiple children? | Handled by rule? |
|-------------------|-------------------------------|------------------|
| `Expression`      | No (always exactly 1)         | Yes (counted)    |
| `SpreadElement`   | Yes (0..N at runtime)         | Yes (skipped)    |
| `IfElement`       | Yes (different counts per branch, branches may contain spreads) | **No — counted as 1** |
| `ForElement`      | Yes (0..N iterations at runtime) | **No — counted as 1** |
| `MapLiteralEntry` | N/A (not used in widget lists) | N/A             |

When the `children` list contains a single `IfElement`, the rule sees
`nonSpreadCount == 1` and `hasSpread == false`, so it reports the violation.
But that `IfElement` can contain:

- A spread in one or both branches (producing many children)
- Different child counts per branch
- A missing `else` branch (producing 0 children conditionally)

### Relevant AST structure

For the real-world case:

```
ListLiteral (children: <Widget>[...])
  └─ IfElement                          ← single CollectionElement
       ├─ condition: sequentialGroup == null || ...
       ├─ thenElement: Expression (NoActivitiesNotice)
       └─ elseElement: SpreadElement    ← spread INSIDE IfElement, invisible
            └─ ...sequentialGroup.map(...)   to the top-level loop
```

The `SpreadElement` is nested inside the `IfElement`'s `elseElement`, not at the
top level of the list. The rule's loop only checks top-level elements, so it
never sees the spread.

Similarly for `ForElement`:

```
ListLiteral (children: <Widget>[...])
  └─ ForElement                         ← single CollectionElement
       ├─ forLoopParts: (final item in items)
       └─ body: Expression (Text(item)) ← produces N children at runtime
```

## Suggested fix

Treat `IfElement` and `ForElement` as potentially multi-child, similar to how
`SpreadElement` is already handled. The simplest approach:

```dart
for (final CollectionElement element in value.elements) {
  if (element is SpreadElement) {
    hasSpread = true;
  } else if (element is IfElement) {
    // Collection if/else can produce varying child counts at runtime.
    // Branches may contain spreads or different numbers of children.
    hasSpread = true;
  } else if (element is ForElement) {
    // Collection for-in produces 0..N children at runtime.
    hasSpread = true;
  } else {
    nonSpreadCount++;
  }
}
```

This reuses the existing `hasSpread` flag (which really means "dynamic child
count possible") to skip reporting.

### Alternative: recursive inspection

For a more precise fix that only skips when the `IfElement` actually contains
a spread or has asymmetric branch counts:

```dart
bool _canProduceMultipleChildren(CollectionElement element) {
  if (element is SpreadElement) return true;
  if (element is ForElement) return true;
  if (element is IfElement) {
    // If no else branch, child count is conditional (0 or N)
    if (element.elseElement == null) return true;
    // If either branch can produce multiple children
    if (_canProduceMultipleChildren(element.thenElement)) return true;
    if (_canProduceMultipleChildren(element.elseElement!)) return true;
  }
  return false;
}
```

However, the simpler approach is recommended. An `IfElement` without an `else`
already means the Column can have 0 children, which makes the "single child"
diagnosis incorrect. And any `IfElement` with an `else` has at minimum two
different runtime shapes, making it unsuitable for replacement with a direct
child widget.

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// IfElement with spread in else branch
Column(children: [
  if (items.isEmpty) const Text('Empty') else ...items.map(Text.new),
])

// IfElement with spread in both branches
Row(children: [
  if (isLoggedIn) ...userMenu else ...guestMenu,
])

// IfElement without else (0 or 1 children)
Column(children: [
  if (showHeader) const Text('Header'),
])

// IfElement with single expression in both branches (still conditional)
Column(children: [
  if (isError) const Text('Error') else const Text('OK'),
])

// ForElement (0..N children)
Column(children: [
  for (final String item in items) Text(item),
])

// ForElement with spread
Column(children: [
  for (final List<Widget> group in groups) ...group,
])

// Nested IfElement inside ForElement
Column(children: [
  for (final item in items)
    if (item.isVisible) Text(item.name),
])

// Should STILL flag (true positives, no change):

Column(children: [Text('Hello')])           // Single static Expression
Row(children: [Icon(Icons.star)])           // Single static Expression
Column(children: <Widget>[someWidget])      // Single variable Expression

// Should STILL skip (existing behavior, no change):

Column(children: [...items])                // Top-level SpreadElement
Row(children: [Text('a'), Text('b')])       // Multiple static children
```

## Impact

Any Flutter codebase using collection-if or collection-for in Column/Row
`children` lists will see false positives. These are extremely common patterns
in Flutter:

- Conditional widgets: `if (showX) WidgetX()`
- Conditional with fallback: `if (data == null) Placeholder() else ...data.map(...)`
- Dynamic lists: `for (final item in items) ItemWidget(item)`

The Dart language specifically added collection-if and collection-for to enable
these patterns in widget trees. Flagging them undermines the utility of the
rule and will drive developers to disable it entirely, hiding legitimate
single-child violations.
