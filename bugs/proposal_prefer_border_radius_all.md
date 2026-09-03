# PROPOSAL: Prefer BorderRadius.all

**Status: Open**

Created: 2026-09-02

**Closes gap:** `pyramid_lint` `prefer_border_radius_all` (pub.dev). Implementing this rule closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

## Summary

Flags `BorderRadius.circular(r)` and suggests `BorderRadius.all(Radius.circular(r))` for consistency with other `BorderRadius` constructors, or vice versa depending on project convention.

## Detection / Behavior

```dart
// Flagged (depending on direction)
BorderRadius.circular(8)

// Suggested
BorderRadius.all(Radius.circular(8))
```

## Quick Fix

Replace `BorderRadius.circular(r)` with `BorderRadius.all(Radius.circular(r))` or the reverse.

## Alternatives Considered

- The two forms are functionally identical. This is a pure style/consistency rule. Low priority — consider Pedantic tier if implemented.
