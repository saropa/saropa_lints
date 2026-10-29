# BUG: `require_mounted_check` — treats an `await` in an `if` block that always returns as an async gap for the later `setState`

**Status: Open**

Created: 2026-10-29
Rule: `require_mounted_check`
File: `lib/src/rules/core/state_management_rules.dart` (class at line 636)
Severity: False positive
Rule version: see diagnostic | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`_AsyncSetStateVisitor` sets `_hasSeenAwait` on any await in source order and never clears it when the await sits in a branch that exits.

---

## Attribution Evidence

```bash
grep -rn "'require_mounted_check'" lib/src/rules/
# lib/src/rules/core/state_management_rules.dart:191:    'require_mounted_check',   (inside RequireStreamControllerDisposeRule.relatedRules)
# lib/src/rules/core/state_management_rules.dart:668:    'require_mounted_check',   (the LintCode of RequireMountedCheckRule)
```

**Rule class:** `RequireMountedCheckRule` (`lib/src/rules/core/state_management_rules.dart:636`)
**Diagnostic as seen in Problems panel:** `[require_mounted_check] Calling setState after an await without checking if the StatefulWidget is still mounted ... {v4} (line 136, col 5)` (source: saropa_lints)

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

`state_management_rules.dart` `_AsyncSetStateVisitor` (line 705): `visitAwaitExpression` sets `_hasSeenAwait = true`; `visitIfStatement` only looks for `mounted` in the condition; `visitMethodInvocation` reports `setState` when `_hasSeenAwait && !_hasMountedCheck`. The visitor is a linear source-order scan with no branch handling.

---

## Why the code is correct

The `await _advance()` is inside an `if` block that always `return`s. Control flow cannot reach line 136 after that await. On every path that reaches the `setState`, no async gap has occurred yet, so `mounted` cannot have changed. The later `if (!mounted) return;` (line 148) guards the later `setState` correctly.

## Affected project locations

- `lib/components/contact/culture/gap_filler/gap_filler_sheet_body.dart:136` (reported by four rules: `use_setstate_synchronously`, `check_mounted_after_async`, `require_mounted_check`, `require_mounted_check_after_await`)

---

## Suggested Fix

Make the "seen await" state flow-sensitive: restore the pre-branch value after a branch that always exits (`return`, `throw`, `break`, `continue`).

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
