# BUG: `avoid_string_substring` — `substring` bounded by a collection-`for` condition is not recognized as guarded

**Status: Open**

Created: 2026-10-29
Rule: `avoid_string_substring`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (line ~1304)
Severity: False positive
Rule version: v3 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`_isGuardedByLengthCheck` accepts a loop condition that bounds the substring indexes for `ForStatement` (line 1403-1405) but not for the equivalent collection-`for` (`ForElement`). The same loop written as a list literal is reported.

---

## Attribution Evidence

```bash
grep -rn "'avoid_string_substring'" lib/src/rules/
lib/src/rules/code_quality/code_quality_avoid_rules.dart:1304:    'avoid_string_substring',
```

Negative grep not applicable: no sibling analyzer repo is checked out beside this one that defines this code; the rule is only defined here.

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:1304`
**Rule class:** `AvoidSubstringRule` — registered in `353:  AvoidSubstringRule.new,`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Standalone. Copied from the real project source (path and lines below) with project-specific types replaced by the real package types where one exists.

Project source: `lib/database/file_backup/encryption/backup_crypto_codec.dart` lines 95-97 (`BackupCryptoCodec.hexToBytes`).

```dart
int _parseHexByte(String s) => int.parse(s, radix: 16);

// Collection-for: the condition `i + 1 < hex.length` bounds substring(i, i + 2).
List<int> hexToBytes(String hex) => <int>[
  for (int i = 0; i + 1 < hex.length; i += 2) _parseHexByte(hex.substring(i, i + 2)), // LINT -- but should NOT lint
];

// Statement form of the same loop is NOT flagged.
List<int> hexToBytesLoop(String hex) {
  final List<int> out = <int>[];
  for (int i = 0; i + 1 < hex.length; i += 2) {
    out.add(_parseHexByte(hex.substring(i, i + 2)));
  }
  return out;
}
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[avoid_string_substring] substring() throws RangeError if start or end indices are out of bounds, causing runtime crashes when input lengths vary. This is especially dangerous with user input, API responses, or dynamically sized strings where the length cannot be guaranteed at compile time. {v3}` reported at 96:63-96:86 of backup_crypto_codec.dart |

---

## AST Context

```
MethodDeclaration (hexToBytes)
  └─ ExpressionFunctionBody
      └─ ListLiteral
          └─ ForElement                      <- not handled by _isGuardedByLengthCheck
              ├─ ForPartsWithDeclarations (int i = 0; i + 1 < hex.length; i += 2)
              └─ MethodInvocation (_parseHexByte)
                  └─ ArgumentList
                      └─ MethodInvocation (hex.substring)  <- reported
```

---

## Root Cause

`code_quality_avoid_rules.dart:1352-1420` (`_isGuardedByLengthCheck`): the parent walk handles `IfStatement`, `ConditionalExpression`, `WhileStatement` (1400-1402) and `ForStatement` (1403-1405, via `_forConditionInvolvesArgs`), then `Block`/`FunctionBody`. There is no branch for `ForElement`, so the walk passes through the `ForElement`, reaches the `FunctionBody` (return false at the end of the chain) and the call is reported. `ForElement.forLoopParts` is a `ForPartsWithDeclarations` with the same `condition` the statement form has.

### Why the code is correct

The loop condition `i + 1 < hex.length` guarantees `i + 2 <= hex.length` for every iteration, so `hex.substring(i, i + 2)` cannot throw. The statement-form loop with an identical condition is already accepted by the rule.

---

## Affected project locations (project: contacts, line numbers before the session's other edits)

- `lib/database/file_backup/encryption/backup_crypto_codec.dart:96`

---

## Suggested Fix

Add `else if (current is ForElement) { final parts = current.forLoopParts; if (parts is ForParts && parts.condition != null && _conditionInvolvesArgs(parts.condition!, argNames)) return true; }` next to the `ForStatement` branch, reusing the `_forConditionInvolvesArgs` logic.

---

## Fixture Gap

The fixture for `avoid_string_substring` should include:

1. `<int>[for (int i = 0; i + 1 < s.length; i += 2) f(s.substring(i, i + 2))]` -- expect NO lint
2. `<String>[for (final n in names) n.substring(3)]` -- expect LINT
3. statement `for (int i = 0; i + 1 < s.length; i += 2) s.substring(i, i + 2);` -- expect NO lint (existing)

---

## Changes Made

None yet.

---

## Tests Added

None yet.

---

## Commits

None yet.

---

## Environment

- saropa_lints version: 17.0.1-beta.2
- Dart SDK version: 3.13.7 (stable) (Thu Oct 22 14:28:57 2026 -0700) on "macos_arm64"
- custom_lint version: not used (analyzer plugin via saropaLintsLsp)
- Triggering project/file: /Users/craighathaway/Documents/src/contacts — lib/database/file_backup/encryption/backup_crypto_codec.dart:96
