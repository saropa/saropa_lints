# Bug: `avoid_nested_assignments` false positive on for-loop update clause

## Summary

The `avoid_nested_assignments` rule incorrectly flags compound assignment
expressions (`i += step`) in the update clause of standard `for` loops. The
update clause of a `for` statement is the canonical location for assignments
like `i++`, `i += step`, `i = next(i)`, etc. These are not "nested" inside
another expression and should not be reported.

## Severity

**False positive** -- produces noise on idiomatic, universally-accepted Dart
(and C-family) patterns. Developers will suppress or ignore the rule entirely
if it flags standard for-loops.

## Reproduction

### Minimal example

```dart
void example(List<Widget> icons) {
  const int itemsPerRow = 3;
  for (int i = 0; i < icons.length; i += itemsPerRow) {
    //                                ^^^^^^^^^^^^^^^^
    //  FLAGGED: avoid_nested_assignments (INFO)
    print(icons.sublist(i, (i + itemsPerRow).clamp(0, icons.length)));
  }
}
```

### Lint output

```
line:col • [avoid_nested_assignments] Assignment expression embedded inside
another expression (e.g. condition, argument, or return). Nested assignments
obscure the data flow and make it unclear whether the intent is comparison,
assignment, or both, increasing the risk of logic errors.
• avoid_nested_assignments • INFO
```

### Additional triggering patterns

All of the following standard for-loop update expressions are falsely flagged:

```dart
// Compound assignment with step
for (int i = 0; i < n; i += 3) { }        // FLAGGED

// Compound subtraction
for (int i = n; i > 0; i -= 1) { }        // FLAGGED

// Multiply step
for (int i = 1; i < n; i *= 2) { }        // FLAGGED

// Bitwise shift
for (int mask = 1; mask < n; mask <<= 1) { }  // FLAGGED

// Plain reassignment
for (int i = 0; i < n; i = next(i)) { }   // FLAGGED
```

Note: `i++` and `i--` are `PostfixExpression` nodes, not `AssignmentExpression`
nodes, so they happen to avoid the rule. But `++i` and `--i` are
`PrefixExpression` nodes and also avoid it. Only the `=`, `+=`, `-=`, `*=`,
`~/=`, `<<=`, `>>=`, `&=`, `|=`, `^=`, `??=` operators produce
`AssignmentExpression` nodes and are affected.

## Real-world occurrence

Found in `saropa/lib/components/contact/detail_panels/nav_icons/nav_icon_list.dart`:

```dart
final List<Widget> rows = <Widget>[];
const int itemsPerRow = 3;
for (int i = 0; i < icons.length; i += itemsPerRow) {
  final List<Widget> rowItems = icons.sublist(
    i,
    (i + itemsPerRow > icons.length) ? icons.length : i + itemsPerRow,
  );
  rows.add(Row(children: rowItems));
}
```

This is a standard chunking loop. The `i += itemsPerRow` update is idiomatic
and not a nested assignment in any meaningful sense.

## Root cause

**File:** `lib/src/rules/control_flow_rules.dart`, lines 934-984
(`AvoidNestedAssignmentsRule`)

The rule registers an `addAssignmentExpression` callback and checks the parent
node. It has an allowlist of parent types that are considered "standalone"
assignment contexts:

| Parent type checked      | Skipped? | Covers                            |
|--------------------------|----------|-----------------------------------|
| `ExpressionStatement`    | Yes      | Standalone `x = 5;`              |
| `ForEachParts`           | Yes      | `for (final x in items)`         |
| `VariableDeclaration`    | Yes      | `final x = getValue();`          |
| `CascadeExpression`      | Yes      | `obj..field = value`             |
| `ExpressionFunctionBody` | Yes      | `() => x = value`                |
| **`ForParts`**           | **No**   | **`for (...; ...; i += step)`**  |

The `ForEachParts` skip was added (for-in loops) but the equivalent skip for
standard `for` loops was not. In the Dart analyzer AST, the update clause of
`for (init; condition; update)` places the update expression(s) under a
`ForPartsWithExpression` or `ForPartsWithDeclarations` node (both subtypes of
`ForParts`). Since `ForParts` is not in the allowlist, any
`AssignmentExpression` in the update clause is flagged.

### Relevant AST structure

For `for (int i = 0; i < n; i += 3) { }`:

```
ForStatement
  └─ ForPartsWithDeclarations  (extends ForParts)
       ├─ variables: int i = 0
       ├─ condition: i < n
       └─ updaters: [AssignmentExpression: i += 3]  ← FALSELY FLAGGED
```

The `i += 3` `AssignmentExpression` node's parent is the
`ForPartsWithDeclarations` node. Since `ForPartsWithDeclarations` (and its
supertype `ForParts`) are not in the allowlist, the rule reports it.

## Suggested fix

Add a skip for `ForParts` in `runWithReporter` alongside the existing
`ForEachParts` skip:

```dart
// Skip if parent is ForEachParts (for-in loop variable)
if (parent is ForEachParts) return;

// Skip if parent is ForParts (standard for-loop update clause)
if (parent is ForParts) return;
```

`ForParts` is the common supertype of both `ForPartsWithDeclarations` and
`ForPartsWithExpression`, so a single check covers all standard for-loop
forms.

### Alternative: check if node is in updaters list

For a more precise fix that only skips the update clause (not the initializer
or condition):

```dart
if (parent is ForParts && parent.updaters.contains(node)) return;
```

This is stricter but arguably unnecessary -- an assignment in the initializer
of a for-loop is also standalone (`int i = start` would be a
`VariableDeclaration`, and `i = start` as a bare expression would have an
`ExpressionStatement` parent in most AST representations). The simpler
`parent is ForParts` check should be sufficient.

## Test cases to add

```dart
// Should NOT flag (false positives to fix):
for (int i = 0; i < 10; i += 1) { }
for (int i = 0; i < 10; i += step) { }
for (int i = n; i > 0; i -= 1) { }
for (int i = 1; i < n; i *= 2) { }
for (int i = 0; i < n; i = next(i)) { }
for (int mask = 1; mask != 0; mask <<= 1) { }

// Should STILL flag (true positives, no change):
if (x = getValue()) { }            // assignment in condition
foo(x = 5);                        // assignment in argument
return x = 5;                      // assignment in return
final y = x = 5;                   // chained assignment
list[i = next()] = value;          // assignment in index expression
```

## Impact

Any Dart codebase using standard `for` loops with compound assignment update
expressions will see false positives. This is a very common pattern --
chunking/batching loops, exponential stepping, bitmask iteration, etc. The
only for-loop update expressions that escape are `i++`/`i--` (postfix) and
`++i`/`--i` (prefix), which use different AST node types.
