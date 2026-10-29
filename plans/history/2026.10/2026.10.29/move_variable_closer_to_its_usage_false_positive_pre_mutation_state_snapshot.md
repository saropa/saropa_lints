# BUG: `move_variable_closer_to_its_usage` — pre-mutation state snapshot flagged

**Status: Open**

Created: 2026-10-29
Rule: `move_variable_closer_to_its_usage`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~2463, `_canMoveCloser` ~2556)
Severity: False positive
Rule version: v9

---

## Summary

The rule flags a local that captures shared state BEFORE a loop of awaited writes changes that state, and is compared with the state AFTER the loop in the return value. Moving the declaration next to its first use would capture the post-mutation state and make the comparison always empty. The declaration position is required for correctness.

---

## Attribution Evidence

```bash
grep -rn "'move_variable_closer_to_its_usage'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_variables_rules.dart:2463:    'move_variable_closer_to_its_usage',
```

**Rule class:** `MoveVariableCloserToUsageRule` (`code_quality_variables_rules.dart:2443`), registered in `lib/saropa_lints.dart:715`.

---

## Reproducer

Standalone and compilable. Real code: `lib/utils/contact/matching/contact_merge_service.dart` lines 210-212 declare, 296-299 use (Saropa contacts app).

```dart
import 'dart:async';

final Set<String> _store = <String>{'a'};

Set<String> loadKeys() => Set<String>.of(_store);

Future<void> mutate(String k) async => _store.add(k);

Future<({Set<String> added, Set<String> removed})> merge(List<String> items) async {
  final bool wasEmpty = _store.isEmpty; // LINT — but must stay here
  final Set<String> keysBefore = loadKeys(); // LINT — but must stay here
  final Set<String> otherBefore = loadKeys(); // LINT — but must stay here

  for (final String item in items) {
    await mutate(item);
  }

  return (
    added: loadKeys().difference(keysBefore),
    removed: keysBefore.difference(loadKeys()).union(otherBefore).union(<String>{'$wasEmpty'}),
  );
}
```

**Frequency:** Every time a snapshot local is declared before a loop and read only after it.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the initializer reads mutable shared state and the statements between it and the use mutate that state |
| **Actual** | `[move_variable_closer_to_its_usage] Variable declared far from its first use, with several unrelated statements in between.` at 210:13, 211:26, 212:26 of the project file |

---

## AST Context

```
MethodDeclaration (mergeGroupDetailed)
  └─ BlockFunctionBody
      └─ TryStatement
          └─ Block
              ├─ VariableDeclarationStatement  ← 210/211/212 reported (name token)
              ├─ ForStatement (awaited dbContactSetPrimary, ContactMatchConfirmations.confirm, ...)
              ├─ IfStatement (byUser)
              ├─ ExpressionStatement (awaited addAliasNotes) ...
              └─ ReturnStatement (ContactMergeOutcome(... exclusionsBefore.difference(...)))  ← first use
```

---

## Root Cause

`_canMoveCloser` (~2556) skips a declaration only when its initializer contains `await` (~2597). It does not consider a synchronous initializer that reads mutable state (a static getter or a call whose result depends on state). The intervening statement count (loop, if, awaits) reaches `_minInterveningStatements = 3` (~2475) and the rule reports. The rule never checks whether the intervening statements can change what the initializer read.

---

## Why the code is correct

The locals are undo snapshots of "what the merge adds to or removes from shared lists". They must be read before the link loop. Moving them down reads the lists after the merge, so `difference` returns an empty set and Undo loses data.

---

## Suggested Fix

In `_canMoveCloser`, do not report when the initializer contains a method call or a non-final property read, and at least one intervening statement contains an `await`. Cheapest variant: skip when any intervening statement contains an `await` and the initializer contains an invocation.

---

## Fixture Gap

1. Snapshot of `loadKeys()` before a loop with `await`, read after the loop: expect NO lint.
2. Literal or constant initializer before unrelated statements: expect LINT (unchanged).
3. Initializer referencing only final locals before unrelated awaits: expect LINT (unchanged).

---

## Affected project locations

- `lib/utils/contact/matching/contact_merge_service.dart` lines 210, 211, 212 (`primaryWasManual`, `exclusionsBefore`, `reviewBefore`).

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- Triggering project/file: Saropa contacts app, `lib/utils/contact/matching/contact_merge_service.dart`

## Status 2026-10-29

Fixed in 17.0.1-beta.4 (see CHANGELOG).
