# BUG: `move_variable_closer_to_its_usage` — fires on loop accumulators declared before a loop

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-05-21
Rule: `move_variable_closer_to_its_usage`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~1925)
Severity: False positive
Rule version: v7 | Since: (unknown) | Updated: (unknown)

---

## Summary

The rule flags an accumulator variable that is declared immediately before a loop but first *read/written inside* the loop body. Such a variable carries state across iterations and **cannot** be moved into the loop without breaking correctness, yet the rule reports it because the first usage line is >10 lines below the declaration. It should not fire when relocating the declaration to its "first use" would move it into a loop (or other narrower scope) that the declaration must enclose.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'move_variable_closer_to_its_usage'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_variables_rules.dart:1942:    'move_variable_closer_to_its_usage',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:1942`
**Rule class:** `MoveVariableCloserToUsageRule` — registered in `lib/saropa_lints.dart:694` (`MoveVariableCloserToUsageRule.new`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `move_variable_closer_to_its_usage` (via `dart analyze`, ground truth)

---

## Reproducer

Minimal accumulator-before-loop pattern (condensed from `saropa_dart_utils/lib/parsing/csv_parse_utils.dart`):

```dart
List<String> parseCsvLine(String line, {String delimiter = ','}) {
  final List<String> fields = <String>[]; // LINT — but MUST stay here (accumulator)
  final StringBuffer current = StringBuffer();
  bool isInQuotes = false;
  for (int i = 0; i < line.length; i++) {
    final String c = line[i];
    if (c == '"') {
      if (isInQuotes && i + 1 < line.length && line[i + 1] == '"') {
        current.write('"');
        i++;
      } else {
        isInQuotes = !isInQuotes;
      }
    } else if (isInQuotes) {
      current.write(c);
    } else if (c == delimiter) {
      fields.add(current.toString()); // first use — ~12 lines below declaration
      current.clear();
    } else {
      current.write(c);
    }
  }
  fields.add(current.toString());
  return fields;
}
```

`fields` is built up across loop iterations. Moving its declaration to "just before its first use" would place it **inside the loop**, resetting it every iteration — a correctness bug. The declaration is already correctly placed (immediately before the loop), so there is nothing to fix.

**Frequency:** Always, for any accumulator (list/map/buffer/counter) whose first reference inside a loop body is >10 lines below its declaration.

### Other real-world instances of the same root cause (saropa_dart_utils)

Same mechanism, different shapes:

- **Accumulator before loop** (cannot move into loop): `fields` (`parsing/csv_parse_utils.dart:3`), `totalMs` (`datetime/duration_parse_utils.dart:8`), `lastIndices` (`list/unique_list_extensions.dart:32`), `result`/`resultIndex` (`string/myers_diff_utils.dart:128-129`), `out` (`string/email_quote_strip_utils.dart:9`, `string/url_extract_utils.dart:28`, `string/fuzzy_search_utils.dart:40`, `string/apply_patch_utils.dart:42`, `string/diff_render_utils.dart:46`), `clusters` (`string/duplicate_doc_utils.dart:12`), `chunks` (`string/text_chunk_utils.dart:12`), `seen`/`out` (`graph/connected_components_utils.dart:9`), `len` (`niche/niche_more_utils.dart:54`), `sum` (`parsing/luhn_utils.dart`).
- **Long own initializer inflates the distance** (no statements actually intervene): `out` declared via a multi-line `List.generate(...)` whose closure body spans >10 lines, then used by the very next `return` (`validation/pii_detector_utils.dart:14`).
- **Multi-use value can't move to one site**: a `const` used in several sibling `if` branches (e.g. `hexRadix` in `parsing/hex_color_utils.dart`) — its first use is >10 lines down but later branches also need it, so it must stay at the top.
- **Sibling declarations consumed together**: 5 `segment*` locals all read by one `return` (`uuid/uuid_v4_utils.dart:42`) — reordering them achieves nothing.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the declaration cannot legally/usefully move closer (accumulator must enclose the loop; multi-use const must enclose all branches; long own-initializer creates no real gap). |
| **Actual** | `[move_variable_closer_to_its_usage] Variable declared far from its first use…` reported on the declaration. |

---

## AST Context

```
MethodDeclaration (parseCsvLine)
  └─ BlockFunctionBody
      └─ Block                                  ← rule registers here (context.addBlock)
          ├─ VariableDeclarationStatement
          │    └─ VariableDeclaration (fields)  ← decl line collected; reported here
          ├─ VariableDeclarationStatement (current)
          ├─ VariableDeclarationStatement (isInQuotes)
          └─ ForStatement
               └─ Block
                   └─ ... IfStatement ...
                       └─ MethodInvocation (fields.add)  ← first usage found here (deep in loop)
```

The rule registers declarations from the **outer** `Block.statements` only, but `_FirstUsageVisitor` (a `RecursiveAstVisitor`) records the first usage **anywhere in descendants**, including inside the `ForStatement` body. It never records that the use site sits inside a loop the declaration must enclose.

---

## Root Cause

`MoveVariableCloserToUsageRule.runWithReporter` (lines ~1956-1999) uses a pure **line-distance** heuristic and never validates that relocation is legal or useful:

```dart
if (useLine != null && useLine - declLine > _minLineDistance) { // _minLineDistance = 10
  reporter.atToken(decl.name, code);
}
```

`_FirstUsageVisitor` (lines ~2003-2023) walks all descendants and records the first `SimpleIdentifier` reference, regardless of whether that reference is inside a loop, nested block, or control-flow branch.

Three concrete defects fall out of this:

### Defect 1 — first usage inside a loop (accumulator)
The rule does not check whether the first-usage node is enclosed by a `ForStatement` / `WhileStatement` / `DoStatement` / `ForEachStatement` that is itself a sibling statement *after* the declaration. When it is, the variable is almost always an accumulator (read **and** assigned across iterations) and moving the declaration inside the loop changes semantics. There is no check for "is the variable assigned more than once / inside the loop" either.

### Defect 2 — distance measured in raw lines, not intervening statements
The message claims "many unrelated statements in between," but the code measures `useLine - declLine`. A variable with a long *own* multi-line initializer (e.g. `List.generate(...)` spanning 11 lines) used by the next statement reports an 11-line "distance" with **zero** intervening statements. Distance should count sibling statements between the declaration statement and the statement containing the first use — not source-line delta — and should exclude the declaration's own initializer span.

### Defect 3 — only the first usage is considered
When a variable is used in several sibling branches (multi-use `const`), moving it to the first use site removes it from the later branches. The rule should not fire when there is more than one usage in distinct sibling scopes (or should require that all usages share a single inner scope the declaration could move into).

---

## Suggested Fix

In `MoveVariableCloserToUsageRule` (around line ~1992), before reporting:

1. **Reject loop-enclosed first use.** Walk the parent chain of the first-usage node up to the registered `Block`. If any ancestor is a `ForStatement` / `ForEachStatement` / `WhileStatement` / `DoStatement` (or any `Block` that is not the registered block), do **not** report — the declaration must remain in the outer scope. (Capture the first-usage `AstNode`, not only its line, in `_FirstUsageVisitor`.)
2. **Count statements, not lines.** Replace `useLine - declLine > 10` with "number of sibling `Statement`s in `node.statements` strictly between the declaration statement and the statement that (transitively) contains the first use." Keep a small threshold (e.g. ≥ 3 intervening statements). This eliminates the long-own-initializer false positive (Defect 2).
3. **Require a single relocatable usage.** Track usage count / distinct enclosing scopes in `_FirstUsageVisitor`; skip when the variable is used in more than one sibling branch, or is assigned after declaration (accumulator guard for Defect 1).

A minimal first cut that kills the bulk of these false positives is step 1 alone: do not flag when the first use is inside a nested loop/block.

---

## Fixture Gap

The fixture at `example/lib/code_quality/move_variable_closer_to_its_usage_fixture.dart` only has a flat `final x = 1; … print(x);` BAD/GOOD pair, and its "20 lines of code" placeholder is a single comment line (so the BAD case's real line distance is ~2 — it may not even trigger the rule today; verify). It should add NO-LINT cases:

1. **Accumulator before a loop** — `final list = <int>[];` then a `for` loop whose body calls `list.add(...)` 10+ lines down → expect **NO** lint.
2. **Long own initializer** — a `List.generate(...)`/collection literal spanning 11+ lines, used by the next statement → expect **NO** lint.
3. **Multi-use const across sibling branches** — a `const` read in two separate `if` branches → expect **NO** lint.
4. **Genuine movable case (positive control)** — a simple local declared, then 4+ unrelated sibling statements, then a single use in straight-line code → expect **LINT**.

---

## Changes Made

<!-- Not yet fixed. Filed from downstream corpus saropa_dart_utils. -->

---

## Tests Added

<!-- Pending fix. -->

---

## Commits

<!-- Pending fix. -->

---

## Environment

- saropa_lints version: 13.10.3
- Dart SDK version: 3.12.0 (stable)
- custom_lint version: (as pinned by saropa_lints 13.10.3)
- Triggering project/file: `saropa_dart_utils` — `lib/parsing/csv_parse_utils.dart`, plus the ~14 instances listed above (verified via `dart analyze`)
