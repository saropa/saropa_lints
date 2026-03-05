# require_debouncer_cancel — False positive when cancel in dispose (State with mixin)

**Resolved:** 2026-03-04

---

## Summary

Rule reported `require_debouncer_cancel` on a `Timer? _debounce` field even when `dispose()` contained `_debounce?.cancel();` and `_debounce = null;`. Occurred for `State<Foo> with WidgetsBindingObserver`: the rule only checked the first `dispose` and/or body source missed the call.

## Fix

- **disposal_rules.dart:** Collect all `dispose` methods (not only the first). For each timer field, treat as cleaned up if any dispose has the cancel call. Check both `body.toSource()` and `method.toSource()` via `isFieldCleanedUp` and `isFieldCleanedUpInSource`.
- **target_matcher_utils.dart:** Added `isFieldCleanedUpInSource(fieldName, methodName, source)` and shared `_fieldCleanedUpPattern` for body and full-method detection.
- **Fixture:** Added `_goodDebouncerWithMixinState` (State with WidgetsBindingObserver, cancel in dispose) so this case must not trigger.
- **Tests:** Fixture structure tests (one BAD expect_lint; GOOD classes include simple and mixin cases).

## References

- Rule: `lib/src/rules/architecture/disposal_rules.dart` — `RequireDebouncerCancelRule`
- Helper: `lib/src/target_matcher_utils.dart` — `isFieldCleanedUp`, `isFieldCleanedUpInSource`
