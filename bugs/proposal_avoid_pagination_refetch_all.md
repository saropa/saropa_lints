# PROPOSAL: Avoid Pagination Refetch All

**Status: Open**

Created: 2026-09-02

## Summary

Flags a pagination implementation that refetches the entire dataset on every page request instead of fetching only the incremental window (the new page's slice).

## Existing Coverage

No rule currently checks this specific pattern. Grep of `lib/src/rules/` for pagination/refetch logic found related-but-distinct rules, all in `lib/src/rules/widget/scroll_rules.dart`:

- `RequirePaginationForLargeListsRule` (`require_pagination_for_large_lists`) — flags `ListView.builder`/`GridView.builder` whose `itemCount` comes from a bulk-loaded list (heuristic variable-name match: `allItems`, `allProducts`, etc.) with no pagination package in use at all. This is the "you have no pagination" check — it does not inspect what an *existing* pagination implementation actually fetches per page.
- `AvoidInfiniteScrollDuplicateRequestsRule` (`avoid_infinite_scroll_duplicate_requests`) — flags firing multiple concurrent fetch requests for the same page (a request-deduplication/debounce concern), not a full-refetch-per-page concern.
- `PreferInfiniteScrollPreloadRule` (`prefer_infinite_scroll_preload`) — flags missing preload-threshold tuning for infinite scroll, unrelated to fetch scope.

None of these inspect the body of a page-fetch function to check whether it re-requests the full dataset (e.g. `fetchAll().sublist(page * pageSize, ...)`) versus an incremental, cursor/offset-bounded request. This proposal is a genuine addition, complementary to `require_pagination_for_large_lists`: that rule catches "no pagination API used"; this rule catches "pagination API used, but implemented wastefully underneath."

## Motivation

A common anti-pattern when a pagination method or `PagingController.onPageRequest` callback is added under time pressure is to keep calling the existing "get everything" endpoint or in-memory full fetch, then slice the requested window client-side (`allData.sublist(offset, offset + pageSize)`) or discard everything except the new page. This defeats the entire purpose of pagination: network payload, decode cost, and (for server-backed sources) database load all scale with total dataset size instead of page size, so page 50 costs the same as page 1 plus 50x the waste. As the dataset grows, per-page latency degrades toward O(n) instead of staying O(page size), and the UI appears to get slower to scroll the further a user goes — a regression that is invisible in small-dataset dev testing and only surfaces in production with real data volumes.

## Detection / Behavior

Triggers when a function invoked from a pagination callback context (`PagingController.onPageRequest`, an `onLoadMore`/`fetchNextPage` handler wired to `ScrollController` or an infinite-scroll widget) calls a full-fetch method (heuristically: a method/endpoint name containing `all`, `fetchAll`, `getAll`, or a repository call with no `offset`/`limit`/`cursor`/`page` argument) and then applies `.sublist(...)`, `.skip(...).take(...)`, or manual index slicing to the full result before appending to the page list.

```dart
// BAD — refetches and re-decodes the entire dataset for every page
Future<void> _onPageRequest(int pageKey) async {
  final all = await repository.fetchAllItems(); // full dataset, every call
  final page = all.sublist(pageKey * pageSize, (pageKey + 1) * pageSize);
  pagingController.appendPage(page, pageKey + 1);
}

// GOOD — server/query does the windowing; only the requested slice is fetched
Future<void> _onPageRequest(int pageKey) async {
  final page = await repository.fetchItems(offset: pageKey * pageSize, limit: pageSize);
  pagingController.appendPage(page, pageKey + 1);
}
```

## Quick Fix

None — manual refactor required. Converting a full-fetch call into an incrementally-windowed one depends on the underlying API/repository supporting offset or cursor parameters, which the tool cannot infer or add automatically.

## Alternatives Considered

Folding this into `require_pagination_for_large_lists` as a second detection branch was considered, since both rules deal with pagination correctness, but the AST shape differs enough (widget-builder `itemCount` inspection vs. tracing a fetch-callback's method body for full-fetch-then-slice) that a separate rule keeps each detector's `runWithReporter` implementation simpler and independently testable.
