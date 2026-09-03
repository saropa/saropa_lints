# PROPOSAL: Stream Subscription Must Be Disposed

**Status: Open**

Created: 2026-09-02

**Closes gap:** `mad_lint` `stream_subscription_must_be_disposed` (pub.dev). Implementing this rule closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

## Summary

Flags `StreamSubscription` fields in `State` classes that are not cancelled in `dispose()`, causing memory leaks and stale callbacks.

## Existing Coverage

Saropa already has `require_stream_subscription_cancel` (`disposal_rules.dart`, line ~1156) which covers this exact pattern. This gap may already be closed — verify rule parity before implementing a duplicate.

## Detection / Behavior

```dart
// Bad — subscription never cancelled
class _MyState extends State<MyWidget> {
  StreamSubscription? _sub;
  void initState() { _sub = stream.listen((_) {}); }
}

// Good
void dispose() { _sub?.cancel(); super.dispose(); }
```

## Quick Fix

Add `_sub?.cancel();` to `dispose()`.

## Alternatives Considered

- Likely closeable as HAVE via `require_stream_subscription_cancel`. Confirm coverage parity first.
