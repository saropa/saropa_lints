# PROPOSAL: Dispose Controllers

**Status: Open**

Created: 2026-09-02

**Closes gap:** `pyramid_lint` `dispose_controllers` (pub.dev). Implementing this rule closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

## Summary

Flags `TextEditingController`, `AnimationController`, `ScrollController`, `TabController`, and other disposable controller fields in `State` classes that are not disposed in `dispose()`.

## Existing Coverage

Saropa has extensive disposal rules in `disposal_rules.dart` covering `TextEditingController`, `AnimationController`, `ScrollController`, `FocusNode`, `StreamSubscription`, and more. This gap is likely already closed — verify rule list parity before implementing.

## Detection / Behavior

```dart
// Bad — controller leaks
class _MyState extends State<MyWidget> {
  final _controller = TextEditingController();
}

// Good
void dispose() { _controller.dispose(); super.dispose(); }
```

## Quick Fix

Add `_controller.dispose();` before `super.dispose()` in the `dispose()` method.

## Alternatives Considered

- Likely closeable as HAVE. Confirm Saropa's disposal rules cover the same controller types.
