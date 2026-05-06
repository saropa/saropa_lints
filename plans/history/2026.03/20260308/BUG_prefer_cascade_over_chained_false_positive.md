# Bug: `prefer_cascade_over_chained` false positive on independent actions

**Status:** Fixed in v2 of rule
**Date reported:** 2026-03-08
**Date fixed:** 2026-03-08

## Problem

The rule fired on ANY 2+ consecutive method calls on the same variable, including independent imperative actions where cascade notation is semantically wrong:

```dart
// Flagged incorrectly — these are independent actions, not configuration
messenger.clearSnackBars();
messenger.showSnackBar(bar);
```

## Root Cause

No distinction between batch/builder patterns (where cascade IS appropriate) and independent action invocations (where cascade is NOT appropriate).

## Fix

Added a heuristic in `_isCascadeCandidate()`:

- **2 calls, same method name** (e.g., `add`/`add`): flag (batch pattern)
- **2 calls, different method names** (e.g., `clear`/`show`): skip (independent actions)
- **3+ calls**: always flag (strong configuration signal)

Also applied the same fix to `prefer_cascade_assignments` (same detection logic).

## Files Changed

- `lib/src/rules/stylistic/stylistic_control_flow_rules.dart`
- `example_style/lib/stylistic_control_flow/prefer_cascade_over_chained_fixture.dart`
- `example_style/lib/stylistic_control_flow/prefer_cascade_assignments_fixture.dart`
