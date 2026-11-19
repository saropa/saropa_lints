# BUG: `check_mounted_after_async` — treats an `await` in an `if` block that always returns as an await before the later `setState`

**Status: Open**

Created: 2026-10-29
Rule: `check_mounted_after_async`
File: `lib/src/rules/core/async_rules.dart` (class at line 1615)
Severity: False positive
Rule version: see diagnostic | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`_hasAwaitBefore` compares source offsets only: any `AwaitExpression` with a smaller offset than the `setState` counts, including one inside a branch that returns.

---

## Attribution Evidence

```bash
grep -rn "'check_mounted_after_async'" lib/src/rules/
# lib/src/rules/core/async_rules.dart:1633:    'check_mounted_after_async',
```

**Rule class:** `CheckMountedAfterAsyncRule` (`lib/src/rules/core/async_rules.dart:1615`)
**Diagnostic as seen in Problems panel:** `[check_mounted_after_async] setState() after await without mounted check. State may be disposed during async gap, causing "setState() called after dispose()" crash. {v5} (line 136, col 5)` (source: saropa_lints)

---

## Reproducer

Standalone (needs the Flutter SDK). Real code: `lib/components/contact/culture/gap_filler/gap_filler_sheet_body.dart` lines 126-157 (`_GapFillerSheetBodyState._save`), the diagnostic is on line 136 col 5.

```dart
import 'package:flutter/widgets.dart';

class Sheet extends StatefulWidget {
  const Sheet({super.key});
  @override
  State<Sheet> createState() => _SheetState();
}

class _SheetState extends State<Sheet> {
  bool _isBusy = false;

  Future<void> _advance() async {}
  Future<bool> _write() async => true;

  Future<void> _save({required bool hasPicks}) async {
    if (!hasPicks) {
      await _advance(); // the only await so far sits in a branch that exits
      return;
    }
    setState(() => _isBusy = true); // LINT — but no await has run on any path that reaches here
    final bool ok = await _write();
    if (!mounted) return;
    setState(() => _isBusy = !ok);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: no `await` can precede the `setState` on any reachable path |
| **Actual** | Diagnostic on `setState` (line 136 col 5) |

---

## AST Context

`ClassDeclaration(_GapFillerSheetBodyState extends State<GapFillerSheetBody>)` > `MethodDeclaration(_save, async)` > `BlockFunctionBody` > `Block` > statements: `IfStatement(!hasPicks)` > `Block` > [`ExpressionStatement(AwaitExpression(_advance()))`, `ReturnStatement`]; then sibling `ExpressionStatement` > `MethodInvocation(setState)` (reported). The only `AwaitExpression` before the reported node is inside the `if` block that ends in `return`.

---

## Root Cause

`async_rules.dart` `CheckMountedAfterAsyncRule.runWithReporter` (line 1663) calls `_hasAwaitBefore(body, node)`: it counts an await when `awaitNode.offset < target.offset`. There is no check that the await sits on a path that can reach the target. `_hasMountedGuard` then only looks for an enclosing `if (...mounted...)` or an early-return mounted guard.

---

## Why the code is correct

The `await _advance()` is inside an `if` block that always `return`s. Control flow cannot reach line 136 after that await. On every path that reaches the `setState`, no async gap has occurred yet, so `mounted` cannot have changed. The later `if (!mounted) return;` (line 148) guards the later `setState` correctly.

## Affected project locations

- `lib/components/contact/culture/gap_filler/gap_filler_sheet_body.dart:136` (reported by four rules: `use_setstate_synchronously`, `check_mounted_after_async`, `require_mounted_check`, `require_mounted_check_after_await`)

---

## Suggested Fix

Make the "seen await" state flow-sensitive: when visiting an `IfStatement` (or any branch) whose then/else block ends in `return`/`throw`/`break`/`continue`, save `the await-before state` before the branch and restore it after visiting a branch that cannot fall through.

---

## Fixture Gap

- GOOD: `if (x) { await a(); return; } setState(...);`
- GOOD: `if (x) { await a(); throw StateError('x'); } setState(...);`
- BAD: `if (x) { await a(); } setState(...);` (branch falls through)
- BAD: `await a(); setState(...);`

---

## Environment

- saropa_lints version: 17.0.1-beta.2 (installed, hosted); rule logic cross-checked against the repo source (17.0.1-beta.3)
- Dart SDK: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project: Saropa contacts app (`/Users/craighathaway/Documents/src/contacts`)

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
