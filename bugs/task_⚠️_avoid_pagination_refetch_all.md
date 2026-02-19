# Task: `avoid_pagination_refetch_all`

## Summary
- **Rule Name**: `avoid_pagination_refetch_all`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.37 Pagination Rules

## Problem Statement

When a paginated list's pull-to-refresh is triggered, some implementations reset the pagination state to page 0 and re-fetch all previously loaded pages. For example, if the user has scrolled to page 5 (50 items), a refresh might re-fetch pages 1-5 sequentially or in parallel — that's 5 network requests instead of 1.

The correct approach for pull-to-refresh in a paginated list is:
1. Reset to page 1 only
2. Fetch fresh page 1 data
3. Replace all cached pages with new page 1 data
4. Lazy-load subsequent pages as the user scrolls

## Description (from ROADMAP)

> Refetching all pages on refresh wastes bandwidth. Detect refresh logic that resets all paginated data.

## Trigger Conditions

1. A pull-to-refresh handler (`RefreshIndicator.onRefresh` callback) that:
   - Loops through pages and re-fetches each: `for (int page = 1; page <= currentPage; page++) await fetchPage(page)`
   - Calls `Future.wait([...page fetches...])` for all currently loaded pages
   - Reloads the entire data set via a single "load all" endpoint

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addNamedExpression((node) {
  if (node.name.label.name != 'onRefresh') return;
  final callback = node.expression;
  if (callback is! FunctionExpression) return;
  if (_hasPageLoopRefetch(callback)) {
    reporter.atNode(node, code);
  }
});
```

`_hasPageLoopRefetch`: detect `for` loops or `Future.wait` patterns inside the refresh callback that fetch multiple pages.

### `PagingController` Detection
If `PagingController.refresh()` is used (from `infinite_scroll_pagination`), that's the correct approach — suppress.

## Code Examples

### Bad (Should trigger)
```dart
// Refreshing ALL pages — wasteful
RefreshIndicator(
  onRefresh: () async {
    for (int page = 0; page < _loadedPages; page++) {  // ← trigger
      final data = await api.fetchPage(page);
      _items.addAll(data);
    }
    setState(() {});
  },
  child: listWidget,
)

// Fetching full dataset on refresh
RefreshIndicator(
  onRefresh: () async {
    final allItems = await api.getAllItems();  // ← trigger: fetches everything
    setState(() => _items = allItems);
  },
  child: listWidget,
)
```

### Good (Should NOT trigger)
```dart
// Reset to page 1 only ✓
RefreshIndicator(
  onRefresh: () async {
    _currentPage = 1;
    _items.clear();
    final firstPage = await api.fetchPage(1);
    setState(() => _items = firstPage);
  },
  child: listWidget,
)

// Using PagingController.refresh() ✓
RefreshIndicator(
  onRefresh: () async {
    _pagingController.refresh();  // handles page reset correctly
  },
  child: listWidget,
)
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| List with 1 page (not actually paginated) | **Suppress** — single page fetch is not "all pages" | Check if `_loadedPages > 1` is detectable |
| `RefreshIndicator` on a non-paginated list | **Suppress** | Need to detect pagination context |
| `getAllItems()` for a small dataset (e.g., user's bookmarks) | **False positive** — small datasets are fine | Can't know size statically |
| `PagingController.refresh()` | **Suppress** | Correct usage |
| Refresh that triggers `BLoC` event (which resets pagination) | **False positive** — might be implemented correctly inside the BLoC | Can't trace into BLoC |
| Test file | **Suppress** | |

## Unit Tests

### Violations
1. `onRefresh` callback with `for` loop re-fetching all pages → 1 lint
2. `onRefresh` callback with `api.getAllItems()` → 1 lint

### Non-Violations
1. `onRefresh` that resets page to 1 and fetches once → no lint
2. `onRefresh: () async { _pagingController.refresh(); }` → no lint
3. Test file → no lint

## Quick Fix

No automated fix.

```
correctionMessage: 'On refresh, reset to page 1 and fetch only the first page. Do not re-fetch all previously loaded pages.'
```

## Notes & Issues

1. **Detection is narrow** — this rule can only detect the `for` loop pattern and `getAllItems()` pattern. BLoC/Riverpod patterns that handle pagination internally are invisible to the linter.
2. **Consider combining** with `require_pagination_for_large_lists` as companion rules in the same implementation file.
3. **`PagingController.refresh()`** from `infinite_scroll_pagination` is the idiomatic Flutter solution — detect and suppress.
