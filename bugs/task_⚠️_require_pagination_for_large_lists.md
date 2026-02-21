# Task: `require_pagination_for_large_lists`

## Summary
- **Rule Name**: `require_pagination_for_large_lists`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.37 Pagination Rules

## Problem Statement

Loading all items from a large dataset at once is one of the most common causes of:
1. **Out-of-memory (OOM)** crashes — 10,000 items × 500 bytes = 5MB just for data, plus widget tree overhead
2. **Slow initial load** — users wait for all 10,000 items to load before seeing anything
3. **UI jank** — building a widget tree for 10,000 items blocks the main thread

`ListView.builder` is lazy by default (only builds visible items), but if `itemCount` is set to a value loaded from a single bulk fetch, the data is still all in memory. True pagination only loads a page of items at a time.

## Description (from ROADMAP)

> Loading all items at once causes OOM and slow UI. Detect ListView/GridView with large itemCount without pagination.

## Trigger Conditions

1. `ListView.builder` or `GridView.builder` with `itemCount` set to a variable that comes from a list loaded in a single fetch
2. `List.length` used as `itemCount` where the list is populated by a single `http.get` / database query
3. No `PageController` / `PagingController` / cursor/pagination pattern visible

**Note**: Cannot know the list size statically. This rule needs heuristics.

### Phase 1 Heuristic
Detect:
- `itemCount: allItems.length` where `allItems` is populated by `await apiClient.getAllItems()` (method name contains `all`, `list`, `load`, `fetch`)
- `itemCount: items.length` where `items` comes from a single large response

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addInstanceCreationExpression((node) {
  if (!_isListViewBuilder(node)) return;
  final itemCountArg = _getItemCountArg(node);
  if (itemCountArg == null) return;
  if (!_isFromSingleBulkLoad(itemCountArg)) return;
  if (_hasPaginationPattern(node)) return;
  reporter.atNode(node, code);
});
```

`_isListViewBuilder`: check constructor is `ListView.builder` or `GridView.builder`.
`_getItemCountArg`: get the `itemCount` named argument.
`_isFromSingleBulkLoad`: check if the variable used for `itemCount` is assigned from a single fetch method.
`_hasPaginationPattern`: check if the enclosing widget or its parent uses `PagingController`, `PageController`, cursor variables.

## Code Examples

### Bad (Should trigger)
```dart
// Loading all items and showing them in a list
class ProductListWidget extends StatelessWidget {
  final List<Product> allProducts;  // could be thousands

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: allProducts.length,  // ← trigger if allProducts loaded in bulk
      itemBuilder: (context, index) => ProductCard(allProducts[index]),
    );
  }
}
```

### Good (Should NOT trigger)
```dart
// Using infinite_scroll_pagination ✓
PagingController<int, Product> _pagingController;

PagedListView<int, Product>(
  pagingController: _pagingController,
  builderDelegate: PagedChildBuilderDelegate<Product>(
    itemBuilder: (context, item, index) => ProductCard(item),
  ),
)

// ListView.builder with explicitly small dataset ✓
final categories = await api.getCategories();  // known small list
ListView.builder(
  itemCount: categories.length,
  itemBuilder: (context, i) => CategoryTile(categories[i]),
)
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `itemCount: 5` (literal, small) | **Suppress** | Only flag variable references |
| `itemCount: items.length` where items are user's own photos (could be thousands) | **Trigger** | Variable count from external source |
| `itemCount: categories.length` (typically small, 5-20 items) | **False positive** — categories are finite | Can't know size statically |
| Project uses `infinite_scroll_pagination` | **Suppress** | `ProjectContext.usesPackage('infinite_scroll_pagination')` |
| Project uses `flutter_bloc` + `bloc_list` pattern | **Suppress** if `BlocPaginatedList` or similar detected | |
| `ListView` (non-builder) with literal children | **Trigger** — ALL children rendered at once | Different case but also important |
| Test file | **Suppress** | |
| `GridView.count(crossAxisCount: 3, children: [...])` | **Trigger if many children** | |
| `SliverList` with delegate | **Trigger similarly** | |

## Unit Tests

### Violations
1. `ListView.builder(itemCount: products.length, ...)` where `products` loaded from single API call → 1 lint
2. `GridView.builder(itemCount: items.length, ...)` same scenario → 1 lint

### Non-Violations
1. `ListView.builder` with `PagingController` → no lint
2. `itemCount: 5` (literal) → no lint
3. Project uses `infinite_scroll_pagination` → no lint
4. Test file → no lint

## Quick Fix

No automated fix — pagination requires architectural changes.

```
correctionMessage: 'Use PagedListView with PagingController (package:infinite_scroll_pagination) or implement cursor-based pagination to avoid loading all items at once.'
```

## Notes & Issues

1. **The biggest challenge** is knowing if the item source is "large". A list of `categories` (5-20 items) is fine; a list of `posts` (potentially thousands) is not. Without knowing the domain, we can't distinguish.
2. **Phase 1 heuristic**: Only trigger when method name explicitly suggests large data: `getAll*`, `fetchAll*`, `loadAll*`, or when the variable is of type `List<T>` from an HTTP response (any `http.get` result deserialized).
3. **`infinite_scroll_pagination`** is the standard Flutter package for this. Detecting its usage and suppressing is key for avoiding false positives in projects that already handle this.
4. **`ListView` without builder**: A `ListView(children: widgets)` is particularly bad — it renders ALL children upfront. This should be a separate check or included here.
