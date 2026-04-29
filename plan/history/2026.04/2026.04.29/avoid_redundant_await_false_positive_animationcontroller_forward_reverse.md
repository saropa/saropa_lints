# BUG FIXED: `avoid_redundant_await` false positive on AnimationController `forward`/`reverse`

**Status: Resolved**

Created: 2026-04-29  
Resolved: 2026-04-29  
Rule: `avoid_redundant_await`  
Primary file: `lib/src/rules/core/async_rules.dart`  
Severity: False positive

---

## Summary

`avoid_redundant_await` incorrectly reported `await _animationController.forward()` and
`await _animationController.reverse()` as redundant. These calls return `TickerFuture`
and are intentionally awaited for animation sequencing.

---

## Root Cause

The rule only treated statically awaitable types (`Future`, `FutureOr`, `Stream`, and
implementers) as valid await targets. `TickerFuture` is not one of those types, so
the check fell through and emitted a diagnostic even for legitimate animation-control
awaits.

---

## Implementation

Added a targeted guard in `AvoidRedundantAwaitRule`:

- New helper `_isAnimationControllerTickerAwait(Expression expression)` detects:
  - method invocations named `forward` or `reverse`
  - invoked on static target type `AnimationController`
- Rule now returns early for this pattern before redundant-await reporting.

This keeps the exception narrow and avoids weakening generic redundant-await detection.

---

## Regression Coverage

Updated `example/lib/async/avoid_redundant_await_fixture.dart` with:

- minimal `AnimationController` / `TickerFuture` fixture types
- `goodAnimationControllerAwaits()` containing:
  - `await controller.forward();`
  - `await controller.reverse();`

Updated `test/async_rules_test.dart` fixture assertions to ensure this regression
scenario remains present.

---

## Validation Notes

- `dart format` run on edited files.
- `ReadLints` reports no diagnostics in edited files.
- `dart test test/async_rules_test.dart` is currently blocked by unrelated
  pre-existing compile errors in other rule files, not by this change.
