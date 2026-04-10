# Bug report (resolved): require_debouncer_cancel

**Rule:** `require_debouncer_cancel`  
**Resolved:** v6.2.1

## Summary

1. **Ignore comment not honored** — With correct syntax (`// ignore: require_debouncer_cancel` on line above), the diagnostic still appeared. **Change:** Rule now reports at the **FieldDeclaration** instead of the VariableDeclaration so the analyzer can associate the diagnostic with the preceding `// ignore:` comment. **Workaround:** Use same-line ignore: `Timer? _debounce; // ignore: require_debouncer_cancel`.

2. **False positive when cancel in dispose()** — Rule reported even when `_debounce?.cancel()` was present in `dispose()`. **Fix:** `isFieldCleanedUp()` in `target_matcher_utils.dart` regex updated from `[?.]` (one char) to `(\\.|\\?\\.)` so `field?.cancel()` is recognized. Rule also checks all `dispose` methods in the class and uses `isFieldCleanedUpInSource` for mixin/override layouts.
