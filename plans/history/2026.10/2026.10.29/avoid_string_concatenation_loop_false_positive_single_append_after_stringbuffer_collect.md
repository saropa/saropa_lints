# BUG: `avoid_string_concatenation_loop` — `+=` on a per-iteration local is flagged as an O(n^2) accumulator

**Status: Fixed**

Created: 2026-10-29
Rule: `avoid_string_concatenation_loop`
File: `lib/src/rules/core/performance_rules.dart` (line ~1360)
Severity: False positive
Rule version: v3 | Since: unknown | Updated: 17.0.1-beta.2

---

## Summary

The `+=` branch (lines 1411-1434) reports any `String +=` inside a loop. It never checks that the target outlives the iteration. The flagged variable is declared inside the loop body, assigned once from `physical[i]`, and appended to once.

---

## Attribution Evidence

```bash
grep -rn "'avoid_string_concatenation_loop'" lib/src/rules/
lib/src/rules/core/performance_rules.dart:1360:    'avoid_string_concatenation_loop',
```

Negative grep not applicable: no sibling analyzer repo is checked out beside this one that defines this code; the rule is only defined here.

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:1360`
**Rule class:** `AvoidStringConcatenationLoopRule` — registered in `809:  AvoidStringConcatenationLoopRule.new,`
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
| **Actual** | `[avoid_string_concatenation_loop] Each += creates new String object, causing O(n²) memory allocations in loops. {v3}` reported at 60:13-60:39 and 77:31-77:57 of vcard_import_line_parser.dart |

---

## AST Context

```
MethodDeclaration (unfold)
  └─ WhileStatement (outer)
      └─ Block
          ├─ VariableDeclarationStatement (String line = physical[i])   <- declared INSIDE the loop
          └─ IfStatement
              └─ ExpressionStatement
                  └─ AssignmentExpression (line += pending.toString())  <- reported
```

---

## Root Cause

`performance_rules.dart:1411-1434`: `context.addAssignmentExpression` -> `operator == PLUS_EQ` (1413) -> `_isInsideLoop(node)` (line 1436, true for `WhileStatement`, `ForElement`, `.forEach`, `.map`) -> `node.readType.isDartCoreString` (1429) -> `reporter.atNode`. The binary-expression branch (1380-1405) correctly requires the target to be an operand (`s = s + x`); the `+=` branch has no counterpart check that the declaration of the target is outside the loop. Quadratic growth needs the same variable to be extended on every iteration.

### Why the code is correct

The method already applies the rule's remedy: fold pieces are accumulated in a `StringBuffer` (comment at lines 50-52 states the quadratic cost it avoids). The remaining `line += pending.toString()` runs at most once per logical line (and once per QP soft break), so total copying is linear in the file size. `line` is a per-iteration local re-created from `physical[i]` on each outer iteration; it is not an accumulator that grows across iterations.

---

## Affected project locations (project: contacts, line numbers before the session's other edits)

- `lib/database/file_backup/import/vcard_import_line_parser.dart:60`
- `lib/database/file_backup/import/vcard_import_line_parser.dart:77`

---

## Suggested Fix

In the `+=` branch resolve `node.writeElement` (a `LocalVariableElement`) and compare its declaration offset to the loop: skip when the variable is declared inside the nearest enclosing loop body. Optionally also skip when the right side is `<StringBuffer>.toString()`.

---

## Fixture Gap

The fixture for `avoid_string_concatenation_loop` should include:

1. `String s = ''; for (final x in xs) { s += x; }` -- expect LINT
2. `for (final x in xs) { String line = x; line += 'y'; out.add(line); }` -- expect NO lint
3. `while (...) { String line = a; if (b.isNotEmpty) line += b.toString(); }` where `b` is a StringBuffer -- expect NO lint

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
