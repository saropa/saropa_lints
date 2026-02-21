# Task: `prefer_master_detail_for_large`

## Summary
- **Rule Name**: `prefer_master_detail_for_large`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §1.20 Responsive & Adaptive Design Rules
- **Priority**: ⭐ Next in line for implementation

## Problem Statement

On smartphones, a list → detail push navigation pattern works well because the screen is narrow. On tablets (width ≥ 600dp by convention) and desktop, stacking navigation wastes horizontal space and forces unnecessary navigation steps. The master-detail pattern (split view) shows the list and detail side-by-side, which is the expected UX on larger screens. Apple's `UISplitViewController` and Android's two-pane layout are platform conventions — not matching them makes apps feel unpolished on large form factors.

## Description (from ROADMAP)

> On tablets, list-detail flows should show both panes (master-detail) rather than stacked navigation.

## Trigger Conditions

Detect patterns where:
1. A `ListView` (or `GridView`) item tap uses `Navigator.push` / `context.push` (GoRouter) / `context.pushNamed`
2. There is NO `MediaQuery.of(context).size.width` check (or `LayoutBuilder`) guarding the navigation call
3. OR there is NO `TwoPane` / `AdaptiveLayout` / column-based layout that handles large screens

### Heuristic
The rule fires when:
- `onTap` / `onPressed` of a `ListTile` / `InkWell` inside a `ListView` directly calls navigation (`Navigator.push`, `context.go`, `context.push`) AND
- The `StatefulWidget` / `StatelessWidget` containing it has no `MediaQuery` width check or `LayoutBuilder` anywhere in its `build` method

## Implementation Approach

### Package Awareness
If the project uses:
- `two_pane` package → suppress (explicitly handled)
- `adaptive_layout` or `flutter_adaptive_scaffold` → suppress
- `go_router` with shell routes → note but don't suppress

### AST Visitor Pattern

```dart
context.registry.addMethodInvocation((node) {
  if (!_isNavigationCall(node)) return;
  if (!_isInsideListItemTap(node)) return;
  if (_hasResponsiveGuard(node)) return;
  reporter.atNode(node, code);
});
```

Key checks:
- `_isNavigationCall`: `Navigator.of(ctx).push(...)`, `Navigator.push(...)`, `context.push(...)`, `context.go(...)`
- `_isInsideListItemTap`: walk parent chain for `ListTile.onTap`, `GestureDetector.onTap`, `InkWell.onTap` inside a `ListView`/`GridView`
- `_hasResponsiveGuard`: walk the enclosing `build()` method for `MediaQuery.of(context).size.width`, `LayoutBuilder`, `AdaptiveLayout`

## Code Examples

### Bad (Should trigger)
```dart
// No responsive check — always pushes on all screen sizes
ListView.builder(
  itemBuilder: (context, index) => ListTile(
    title: Text(items[index].name),
    onTap: () => Navigator.push(  // ← trigger
      context,
      MaterialPageRoute(builder: (_) => DetailPage(item: items[index])),
    ),
  ),
)
```

### Good (Should NOT trigger)
```dart
// Responsive check present ✓
Widget build(BuildContext context) {
  final isWide = MediaQuery.of(context).size.width >= 600;

  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 600) {
        return Row(children: [
          Expanded(child: ListPane(onSelect: (item) => setState(() => _selected = item))),
          Expanded(child: DetailPane(item: _selected)),
        ]);
      }
      return ListView.builder(
        itemBuilder: (context, i) => ListTile(
          onTap: () => Navigator.push(...),
        ),
      );
    },
  );
}

// Using adaptive scaffold ✓
AdaptiveLayout(
  body: SlotLayout(config: {...}),
  secondaryBody: SlotLayout(config: {...}),
)
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `onTap` navigates but enclosing widget has `LayoutBuilder` | **Suppress** — developer is aware of breakpoints | Walk the enclosing `build()` for any `LayoutBuilder` |
| Navigation inside a `Dialog` (not a list item) | **Suppress** — dialogs don't apply master-detail | Check parent context |
| `GridView` photo gallery tapping to fullscreen | **Suppress** — fullscreen overlays are fine on tablets too | This is a known exception but hard to detect statically |
| GoRouter shell routes with side nav | **Suppress** if `ShellRoute` is used in router config | `ProjectContext`-level check on route config |
| App is phone-only (`supportedDevices` restricted) | **Suppress** ideally, but detecting this from pubspec/manifest is out of scope for Phase 1 | Note as limitation |
| `ListTile.onTap` that pops instead of pushes | **Suppress** | Only flag push/go navigation |
| Test files | **Suppress** | `ProjectContext.isTestFile` |
| `PageView` swipe (not tap) | **Suppress** | Not a navigation call |

## Unit Tests

### Violations
1. `ListView.builder` with `ListTile.onTap: () => Navigator.push(...)` and no `MediaQuery`/`LayoutBuilder` in the widget → 1 lint
2. `GridView` item tap with `context.push(...)` and no responsive guard → 1 lint
3. `InkWell.onTap: () => context.go('/detail')` inside `ListView` child → 1 lint

### Non-Violations
1. Same list but `build()` method contains `LayoutBuilder(builder: (ctx, constraints) {...})` → no lint
2. Same list but `build()` reads `MediaQuery.of(context).size.width` → no lint
3. Project uses `adaptive_layout` package → no lint
4. `ListTile.onTap` calls `Navigator.pop()` (not push) → no lint
5. Test file → no lint

## Quick Fix

No automated quick fix — the change requires structural refactoring of the widget tree.

```
correctionMessage: 'Use LayoutBuilder or MediaQuery to detect wide screens and show a master-detail (two-pane) layout on tablets.'
```

## Notes & Issues

1. **False positive risk is HIGH** — many apps legitimately use Navigator.push in list taps and handle responsive design elsewhere (e.g., in a parent `ResponsiveBuilder`). The "has responsive guard anywhere in `build()`" heuristic will miss cases where the guard is in a parent widget.
2. **Consider marking as `[TOO-COMPLEX]` for ROADMAP_DEFERRED** — detecting responsive guards in parent widgets requires cross-widget analysis. This might be better suited for a deferred rule.
3. **Phase 1 scope**: Only fire when there is NO `MediaQuery` / `LayoutBuilder` / `LayoutBuilder` call in the ENTIRE `build()` method of the immediate enclosing widget. This will have some false negatives (parent handles it) but low false positives.
4. **Suppression comment**: Consider supporting `// ignore: prefer_master_detail_for_large` for cases where developers intentionally use stacked nav.
5. **Companion rule**: `require_foldable_awareness` (§1.20) is a related follow-up rule.
