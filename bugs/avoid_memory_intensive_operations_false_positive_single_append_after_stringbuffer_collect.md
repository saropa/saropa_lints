# BUG: `avoid_memory_intensive_operations` — `+=` of a `StringBuffer` result once per outer iteration is flagged as quadratic

**Status: Open**

Created: 2026-10-29
Rule: `avoid_memory_intensive_operations`
File: `lib/src/rules/core/performance_rules.dart` (line ~3027)
Severity: False positive
Rule version: v2 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

`_StringConcatVisitor` reports every `String +=` under any `while`/`for` body. It does not check that the target is the same variable across iterations (an accumulator) or that the right-hand side comes from a `StringBuffer`.

---

## Attribution Evidence

```bash
grep -rn "'avoid_memory_intensive_operations'" lib/src/rules/
lib/src/rules/core/performance_rules.dart:3027:    'avoid_memory_intensive_operations',
```

Negative grep not applicable: no sibling analyzer repo is checked out beside this one that defines this code; the rule is only defined here.

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:3027`
**Rule class:** `AvoidMemoryIntensiveOperationsRule` — registered in `1289:  AvoidMemoryIntensiveOperationsRule.new,`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` / `saropaLintsLsp`

---

## Reproducer

Standalone. Copied from the real project source (path and lines below) with project-specific types replaced by the real package types where one exists.

Project source: `lib/database/file_backup/import/vcard_import_line_parser.dart` lines 38-81 (`VCardImportLineParser.unfold`); the append at line 77 is the single flush per logical line, the one at line 60 flushes only at a quoted-printable soft break.

```dart
String unfold(List<String> physical) {
  final List<String> logical = <String>[];
  int i = 0;
  while (i < physical.length) {
    String line = physical[i];
    i++;
    // Fold pieces are collected in a StringBuffer (linear), not appended to `line`.
    final StringBuffer pending = StringBuffer();
    while (i < physical.length && physical[i].startsWith(' ')) {
      pending.write(physical[i].replaceFirst(RegExp(r'^ '), ''));
      i++;
    }
    if (pending.isNotEmpty) line += pending.toString(); // LINT -- but should NOT lint
    logical.add(line);
  }
  return logical.join('\n');
}
```

**Frequency:** Always for this pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic (code is correct) |
| **Actual** | `[avoid_memory_intensive_operations] String concatenation using += inside a loop creates a new String object on every iteration, resulting in O(n squared) memory allocations. ... {v2}` reported at 60:13-60:39 and 77:31-77:57 of vcard_import_line_parser.dart |

---

## AST Context

```
ClassDeclaration (VCardImportLineParser)
  └─ MethodDeclaration (unfold)
      └─ BlockFunctionBody > Block
          └─ WhileStatement (outer, i < physical.length)
              └─ Block
                  └─ IfStatement (pending.isNotEmpty)
                      └─ ExpressionStatement
                          └─ AssignmentExpression (line += pending.toString())  <- reported
```

---

## Root Cause

`performance_rules.dart:3044-3050`: `context.addWhileStatement` visits the whole body with `_StringConcatVisitor` (class at 3053). `visitAssignmentExpression` (3060) reports when `node.operator.type == TokenType.PLUS_EQ`, the left side is string-like (with `fallback: true`, i.e. even when the type is unknown) and the right side is a `String`. There is no check that the variable is declared outside the loop (an accumulator), that the right-hand side is not from a `StringBuffer`, or that the statement runs once per iteration rather than growing a long string repeatedly.

### Why the code is correct

The method already applies the rule's remedy: fold pieces are accumulated in a `StringBuffer` (comment at lines 50-52 states the quadratic cost it avoids). The remaining `line += pending.toString()` runs at most once per logical line (and once per QP soft break), so total copying is linear in the file size. `line` is a per-iteration local re-created from `physical[i]` on each outer iteration; it is not an accumulator that grows across iterations.

---

## Affected project locations (project: contacts, line numbers before the session's other edits)

- `lib/database/file_backup/import/vcard_import_line_parser.dart:60`
- `lib/database/file_backup/import/vcard_import_line_parser.dart:77`

---

## Suggested Fix

Report only when the compound-assignment target is a variable declared OUTSIDE the loop whose body contains the assignment (a true accumulator), same as the sibling rule `avoid_string_concatenation_loop` could do. Skip when the right side is `buffer.toString()` for a `StringBuffer` declared inside the same loop iteration.

---

## Fixture Gap

The fixture for `avoid_memory_intensive_operations` should include:

1. `String s = ''; for (...) { s += x; }` -- expect LINT
2. per-iteration local: `for (...) { var line = a; line += b; out.add(line); }` -- expect NO lint
3. `line += buffer.toString()` where `buffer` and `line` are both declared inside the loop body -- expect NO lint

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
- Triggering project/file: /Users/craighathaway/Documents/src/contacts — lib/database/file_backup/import/vcard_import_line_parser.dart:60, 77
