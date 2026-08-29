# BUG: `avoid_unguarded_debug` — Early-return guard not recognized

**Status: Fixed**

Created: 2026-08-29
Rule: `avoid_unguarded_debug`
File: `lib/src/rules/testing/debug_rules.dart` (line ~122)
Severity: False positive
Rule version: v3

---

## Summary

`avoid_unguarded_debug` flags `debugPrint()` calls that are guarded by an early-return pattern (`if (!kDebugMode) return;`) at the top of the enclosing function. The rule only recognizes direct wrapping `if (kDebugMode) { ... }` blocks, not the logically equivalent early-return guard.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_unguarded_debug'" lib/src/rules/
# Result: lib/src/rules/testing/debug_rules.dart:122: 'avoid_unguarded_debug',
```

---

## Reproduction

```dart
Future<void> _printBuildIdentityBanner() async {
  try {
    if (!kDebugMode) return; // <-- guard

    final PackageInfo info = await PackageInfo.fromPlatform();

    debugPrint('=' * 78);  // flagged — FP
    debugPrint('BUILD IDENTITY  —  version ${info.version}');  // flagged — FP
  } on Object catch (error, stack) {
    debugException(error, stack);
  }
}
```

All four `debugPrint` calls are unreachable in release mode due to the early return at `if (!kDebugMode) return;`. The rule should recognize this as a valid guard.

---

## Expected Behavior

No diagnostic when every path to the `debugPrint` call is dominated by a `kDebugMode` / `!kDebugMode` early-return check.

---

## Workaround

`// ignore: saropa_lints/avoid_unguarded_debug` with rationale on each call site.

---

## Finish Report (2026-08-29)

### Defect

`AvoidUnguardedDebugRule._isGuarded()` only recognized `debugPrint()` as guarded when it was a descendant of an `if (kDebugMode)` block. The logically equivalent early-return pattern — `if (!kDebugMode) return;` followed by `debugPrint()` as a subsequent statement in the same block — was not detected, producing false positives.

### Fix

The `_isGuarded()` method now delegates early-return guard detection to a new shared utility (`early_exit_guard_utils.dart`) via `hasDominatingEarlyExitGuard()`. The utility walks ancestor blocks and scans preceding statements for if-statements whose then-branch exits and whose condition matches a caller-supplied predicate. The debug rule supplies `_isNegatedDebugGuardCondition` as the predicate, which recognizes `!kDebugMode`, `kDebugMode == false`, and `kDebugMode != true` forms.

### Shared utility extraction

Five independent reimplementations of "preceding early-exit guard" detection were consolidated into `lib/src/early_exit_guard_utils.dart`:

| Utility function | Purpose |
|---|---|
| `containsEarlyExit(Statement)` | Any child is return/throw/break/continue |
| `endsWithEarlyExit(Statement)` | Last statement exits (multi-statement blocks) |
| `findPrecedingGuardInBlock(Block, AstNode, predicate)` | Single-block scanner |
| `hasDominatingEarlyExitGuard(AstNode, predicate)` | Ancestor-walking wrapper |

Consumers refactored:
- `debug_rules.dart` — `_isGuarded()` uses `hasDominatingEarlyExitGuard`
- `collection_rules.dart` — `_isCollectionGuardedByEarlyReturn()` uses `hasDominatingEarlyExitGuard`
- `async_rules.dart` — `_hasEarlyReturnGuardInBlock()` uses `containsEarlyExit`
- `type_rules.dart` — `_isAfterEarlyReturn()` uses `endsWithEarlyExit`
- `code_quality_avoid_rules.dart` — `_hasPrecedingEarlyExitGuard()` uses `findPrecedingGuardInBlock`

### Known limitations (pre-existing, documented)

The ancestor walk crosses closure/function-expression boundaries. For compile-time constants (`kDebugMode`) this is correct — the closure can only be created inside the guarded zone. For runtime-mutable guards (`isDebugActive`, `MainSettings.isDebugMode`, etc.) this is technically unsound if the guard changes between closure creation and execution. This trade-off is shared with the pre-existing wrapping-`if` pattern and is documented in a new comment on `_isGuarded()`.

### Files changed

- `lib/src/early_exit_guard_utils.dart` — new shared utility for early-exit guard detection
- `lib/src/rules/testing/debug_rules.dart` — refactored `_isGuarded()` to use shared utility
- `lib/src/rules/data/collection_rules.dart` — replaced local `_containsEarlyExit` and guard walk
- `lib/src/rules/core/async_rules.dart` — replaced local `_containsEarlyExit`
- `lib/src/rules/data/type_rules.dart` — replaced inline exit detection with `endsWithEarlyExit`
- `lib/src/rules/code_quality/code_quality_avoid_rules.dart` — replaced local guard scanner and `_containsEarlyExit`
- `example/lib/debug/avoid_unguarded_debug_fixture.dart` — added 7 fixture cases (early return, try-block, braces, `== false`, `!= true`, multi-statement, before-guard negative)
- `CHANGELOG.md` — added `[15.2.4] — Unreleased` section with fix entry and maintenance note
