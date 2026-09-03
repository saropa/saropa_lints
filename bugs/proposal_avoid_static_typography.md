# PROPOSAL: Avoid Static Typography

**Status: Open**

Created: 2026-09-02

**Closes gap:** `ripplearc_linter` `avoid_static_typography` (pub.dev). Implementing this rule closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

## Summary

Flags hardcoded `TextStyle` constants and inline `TextStyle(...)` constructors, encouraging use of `Theme.of(context).textTheme` instead. Hardcoded styles bypass theming, dark mode, and accessibility text scaling.

## Detection / Behavior

```dart
// Bad — hardcoded style ignores theme
Text('Hello', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold));

// Good — respects theme
Text('Hello', style: Theme.of(context).textTheme.bodyLarge);
```

## Quick Fix

None — manual refactor required. The developer must choose the appropriate theme text style.

## Alternatives Considered

- Saropa's `avoid_hardcoded_color` covers colors but not text styles. This is a complementary theming rule.
