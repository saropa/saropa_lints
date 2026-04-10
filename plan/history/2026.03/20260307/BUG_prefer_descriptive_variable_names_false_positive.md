# Bug: `prefer_descriptive_variable_names` false positive on short-lived swap variables

**Status:** Fixed in v4
**Rule:** `prefer_descriptive_variable_names` (v3 → v4)
**Severity:** False positive — flags valid code that should not trigger
**Plugin version:** Fixed in saropa_lints v8.0.9+

## Resolution

Fixed in v4 of the rule. Three changes:

1. **Small-block exemption**: Variables in blocks with ≤5 statements are now skipped. Short methods like `take()` / `pop()` / `swap()` patterns no longer trigger.

2. **Common short names**: Added `i`, `j`, `k` (loop indices), `e` (exception/error), and `n` (count) to the allowed short names list.

3. **For-loop index skip**: Variables declared in `ForPartsWithDeclarations` (e.g., `for (var i = 0; ...)`) are now skipped regardless of block size.

## Original problem

The rule flagged single-use temporary variables in very short methods (e.g., `final r = _pending;` in a 3-line `take()` method) as needing longer names, even when the variable's purpose was immediately obvious from context.
