# PROPOSAL: Flag Interactive Gesture Handlers Missing Haptic Feedback

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none (no existing `saropa_lints` rule inspects gesture-handler bodies for tactile-feedback UX conventions)

---

## Summary

Add a rule that flags interactive gesture callbacks (`onLongPress`, `onTap` on destructive/confirming actions, drag-and-drop reorder handlers, swipe-to-dismiss) that perform a significant state change but never call `HapticFeedback.*()`, where platform UX convention expects tactile confirmation.

**Closes gap:** DCM `prefer-haptic-feedback-on-interaction` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

iOS and Android platform UX guidelines both call for haptic confirmation on long-press context menus, drag-to-reorder, and destructive/irreversible actions (delete, swipe-to-dismiss) — its absence makes an app feel unresponsive or "cheap" compared to platform-native apps, and is a common polish gap flagged in UX review passes. `flutter`'s `HapticFeedback` class (`services.dart`) makes this a one-line addition (`HapticFeedback.mediumImpact()`, `.selectionClick()`, etc.), so the fix is trivial once the gap is surfaced — the value is in catching the omission during code review rather than after a UX audit.

DCM (dcm.dev) ships `prefer-haptic-feedback-on-interaction` for exactly this convention. `saropa_lints` has no equivalent rule — grep for `HapticFeedback` across `lib/src/rules/` returns zero rule definitions.

---

## Detection / Behavior

Flag `onLongPress` callback bodies (on `GestureDetector`, `InkWell`, `ReorderableListView` item handles) and `Dismissible.onDismissed`/`confirmDismiss` callbacks that contain no call to `HapticFeedback.*` anywhere in their body (including calls made in a helper method the callback delegates to a single level deep, resolved by name only — not full call-graph analysis). `onTap` is intentionally excluded from the default detection set (too broad — most taps are simple navigation, not confirmable-destructive actions) except when the tap handler's block also shows a `showDialog`/`AlertDialog` confirmation pattern immediately preceding a destructive call (e.g. a delete confirmation), a narrower and higher-signal heuristic.

### Should flag (bad code)

```dart
ReorderableListView(
  onReorder: (oldIndex, newIndex) {
    setState(() => items.insert(newIndex, items.removeAt(oldIndex))); // LINT — no haptic on reorder
  },
  children: items.map((e) => ListTile(key: ValueKey(e), title: Text(e))).toList(),
)

GestureDetector(
  onLongPress: () => _showContextMenu(context), // LINT — long-press with no haptic
  child: const Icon(Icons.more_vert),
)
```

### Should pass (good code)

```dart
ReorderableListView(
  onReorder: (oldIndex, newIndex) {
    HapticFeedback.mediumImpact(); // OK
    setState(() => items.insert(newIndex, items.removeAt(oldIndex)));
  },
  children: items.map((e) => ListTile(key: ValueKey(e), title: Text(e))).toList(),
)

GestureDetector(
  onLongPress: () {
    HapticFeedback.selectionClick(); // OK
    _showContextMenu(context);
  },
  child: const Icon(Icons.more_vert),
)
```

---

## Proposed Tier

Tier: Comprehensive
Justification: this is a UX-polish convention, not a correctness or accessibility requirement — omitting haptic feedback does not break functionality or exclude users, so it does not meet the bar for Essential/Recommended. It is a legitimate low-cost improvement to surface for teams doing a polish pass, matching where saropa places other "nice to have" UX-consistency rules.

---

## Edge Cases

1. **Delegated callbacks** (`onLongPress: _handleLongPress` referencing a named method elsewhere in the class) — the rule should resolve one level into the referenced method body before giving up, since this is a common refactor pattern; deeper delegation chains are out of scope for a heuristic AST rule (documented false-negative risk).
2. **Test/example files** — should be skipped via the existing `ProjectContext.isTestFile`-style check; test doubles for gesture handlers have no UX requirement.
3. **Already-centralized haptic wrapper** (a project-defined `AppHaptics.confirm()` helper instead of calling `HapticFeedback` directly) — should pass if the wrapper's own body calls `HapticFeedback.*` at least once in the file, otherwise the rule cannot distinguish it from a no-op helper; document this as a known heuristic limit rather than attempting whole-program call-graph resolution.
4. **Platforms where haptics are unavailable** (web, most desktop targets) — `HapticFeedback` calls are no-ops on unsupported platforms rather than throwing, so no platform gating is needed in the rule; calling it unconditionally is the correct pattern and should never itself be flagged.

---

## Alternatives Considered

- **Flag every `onTap` without haptic feedback** — rejected as far too broad; the overwhelming majority of taps are simple navigation/selection where haptic feedback is not a platform convention, and flagging them all would make the rule unusable noise.
- **Whole-program call-graph resolution to find delegated haptic calls at any depth** — more accurate but a large engineering investment for a Comprehensive-tier polish rule; the one-level-delegation heuristic is proposed as the pragmatic v1 scope.

---

## Decision

---

## Implementation Notes

---

## Commits
