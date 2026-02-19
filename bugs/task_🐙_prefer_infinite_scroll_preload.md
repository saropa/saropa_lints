# Task: `prefer_infinite_scroll_preload`

## Summary
- **Rule Name**: `prefer_infinite_scroll_preload`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §1.52 Infinite Scroll Rules
- **GitHub Issue**: [#28](https://github.com/saropa/saropa_lints/issues/28)
- **Priority**: 🐙 Has active GitHub issue

## Problem Statement

Infinite scroll lists that load the next page only when the user reaches the EXACT end of the list (scroll position = max) cause a visible loading gap. The user scrolls to the bottom, sees a spinner, and must wait for the next page to load. The correct pattern is to trigger loading when the user is at 80–90% of the current list (the preload threshold), so the next page arrives before the user reaches the bottom.

This is a UX performance issue, not a correctness issue — hence INFO severity.

## Description (from ROADMAP)

> Load next page before reaching end. Detect ScrollController listener triggering at 100% scroll.

## Trigger Conditions

Detect:
1. `ScrollController.addListener(...)` callback that checks `_scrollController.position.pixels == _scrollController.position.maxScrollExtent`
2. `_scrollController.offset >= _scrollController.position.maxScrollExtent`
3. Any equality or `>=` comparison against `maxScrollExtent` without a preload buffer

The rule fires when the comparison uses `==` or `>= maxScrollExtent` (100%) instead of `>= maxScrollExtent * 0.8` or `>= maxScrollExtent - preloadBuffer`.

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addBinaryExpression((node) {
  if (!_isScrollPositionComparison(node)) return;
  if (!_isAtMaxExtent(node)) return;  // == or >= maxScrollExtent
  if (_hasPreloadBuffer(node)) return;
  reporter.atNode(node, code);
});
```

`_isScrollPositionComparison`: check if LHS is `controller.position.pixels` or `controller.offset`.
`_isAtMaxExtent`: check if RHS is `controller.position.maxScrollExtent` (possibly with `==` or `>=`).
`_hasPreloadBuffer`: check if the RHS includes arithmetic like `- 200` or `* 0.8`.

### NotificationListener pattern
Also detect:
```dart
NotificationListener<ScrollNotification>(
  onNotification: (notification) {
    if (notification.metrics.pixels == notification.metrics.maxScrollExtent) {  // ← trigger
      loadMore();
    }
  },
)
```

## Code Examples

### Bad (Should trigger)
```dart
// Loading at 100% scroll — causes visible gap
void _onScroll() {
  if (_controller.position.pixels == _controller.position.maxScrollExtent) {  // ← trigger
    _loadNextPage();
  }
}

// Using >= maxScrollExtent — same problem
if (_scrollController.offset >= _scrollController.position.maxScrollExtent) {  // ← trigger
  _loadMore();
}

// NotificationListener version
NotificationListener<ScrollNotification>(
  onNotification: (n) {
    if (n.metrics.pixels >= n.metrics.maxScrollExtent) {  // ← trigger
      loadNextPage();
    }
    return false;
  },
)
```

### Good (Should NOT trigger)
```dart
// Preloading at 80% ✓
void _onScroll() {
  if (_controller.position.pixels >= _controller.position.maxScrollExtent * 0.8) {
    _loadNextPage();
  }
}

// Preloading with fixed buffer ✓
if (_scrollController.offset >= _scrollController.position.maxScrollExtent - 200) {
  _loadMore();
}

// Third-party package handling pagination ✓
// (flutter_bloc's InfiniteListBloc, infinite_scroll_pagination, etc.)
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Project uses `infinite_scroll_pagination` package | **Suppress** — package handles preloading | `ProjectContext.usesPackage('infinite_scroll_pagination')` |
| `scrollController.jumpTo(maxScrollExtent)` (programmatic) | **Suppress** — not a listener trigger | Check context — assignment vs comparison |
| Reverse list (`reverse: true`) | **Trigger** — same pattern, different scroll direction | Same detection; note in message |
| Horizontal scroll with same pattern | **Trigger** — applies equally | |
| `position.atEdge` check | **Trigger** — `atEdge` is equivalent to `pixels == maxScrollExtent` | Also detect `position.atEdge` comparisons |
| Load-once list (no pagination) | **Suppress** — checking scroll position for a non-paginated list is fine | Hard to know statically if list is paginated |
| `pixels > maxScrollExtent - 50` (small buffer) | **Suppress** — some preloading exists | Any subtraction counts as a buffer |
| Test file | **Suppress** | |
| Scroll-to-top FAB (checking position for visibility) | **Suppress** — not loading more pages | Check what the callback does (loads data vs. shows FAB) |

## Unit Tests

### Violations
1. `_controller.position.pixels == _controller.position.maxScrollExtent` inside `addListener` → 1 lint
2. `_controller.offset >= _controller.position.maxScrollExtent` → 1 lint
3. `NotificationListener` with `metrics.pixels >= metrics.maxScrollExtent` → 1 lint

### Non-Violations
1. `_controller.position.pixels >= _controller.position.maxScrollExtent * 0.8` → no lint
2. `_controller.offset >= _controller.position.maxScrollExtent - 300` → no lint
3. Project uses `infinite_scroll_pagination` → no lint
4. Test file → no lint
5. `_controller.jumpTo(_controller.position.maxScrollExtent)` (not a comparison) → no lint

## Quick Fix

Offer "Add preload buffer (80% threshold)":
```dart
// Before:
if (_controller.position.pixels == _controller.position.maxScrollExtent) {

// After:
if (_controller.position.pixels >= _controller.position.maxScrollExtent * 0.8) {
```

This is a safe automated fix that improves UX without breaking functionality.

## Notes & Issues

1. **The 80% threshold is a heuristic** — the correct threshold depends on item height and network speed. The quick fix should use `0.8` as a reasonable default but the correction message should explain it's configurable.
2. **`position.atEdge` property** — Flutter's `ScrollPosition` has an `atEdge` getter that returns `true` when at either end. This should also be detected.
3. **GitHub Issue #28** — check for additional real-world examples and edge cases.
4. **Companion rule**: `require_infinite_scroll_error_recovery` (§1.52) handles the error state — implement together.
5. **`infinite_scroll_pagination` suppression** is important — that package explicitly handles preloading via `PagingController`.
6. **The quick fix changes behavior** (loads slightly earlier) which is almost always desirable, but developers should be informed. Add a note in the fix description.
